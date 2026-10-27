# ADR-002: Local Zone'da Fargate yerine ECS on EC2

- **Durum:** Kabul edildi
- **Tarih:** 2026-10-27

## Bağlam

Frankfurt baseline'ında WordPress ECS Fargate üzerinde çalışıyor. Fargate
Local Zone'larda desteklenmiyor; İstanbul Local Zone'da (`eu-central-1-ist-1a`)
EC2 (C7i, M7i, R7i), ECS ve EKS var.

## Karar

Local Zone'da ECS'i bir EC2 capacity provider ile çalıştırıyoruz
(`modules/ecs-ec2-capacity`):

- ECS-optimized Amazon Linux 2023 AMI, `m7i.large`, Auto Scaling Group
- Managed scaling: ECS, yerleşemeyen task olunca instance ekler, boşalanı kapatır
- Managed termination protection ve draining: task çalışan instance habersiz kapanmaz
- Task tanımı aynı (`awsvpc`, aynı imaj, aynı ortam değişkenleri); yalnızca
  `requires_compatibilities` ve servis kapasite stratejisi değişiyor
- Task'lar `spread(instanceId)` ile farklı instance'lara dağıtılır
- Instance'lara erişim SSH değil, Session Manager

EKS düşünülmedi: tek servisli bir uygulama için kontrol düzlemi maliyeti ve
operasyon yükü fazla, Frankfurt tarafıyla karşılaştırma da bozulurdu.

## Sonuçlar

- **Operasyon yükü:** AMI güncellemesi bizde. Launch template'teki AMI değişince
  ASG instance refresh ile instance'ları sırayla yeniler; ECS her birini önce
  boşaltır. AMI her `apply`'da SSM parametresinden en güncel haliyle okunur.
- **Kapasite:** ENI trunking kapalı; `m7i.large` en fazla 2 task taşır. Rolling
  deploy'da (%200) 2 task için geçici olarak 2 instance gerekir. ASG en fazla 4.
- **Ölçeklenme hızı:** Yeni task yer bulamazsa önce instance açılmalı; Fargate'e
  göre dakikalar mertebesinde yavaş. Faz 8'de ölçülecek.
- **Maliyet:** Boşta duran kapasite de faturalanır (en az 1 instance).
