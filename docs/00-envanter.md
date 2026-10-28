# 00 — Envanter (Faz 0.1)

Bu repo ve [wordpress-shop-demo](https://github.com/egeeuzun/wordpress-shop-demo)
imajının bugün kurduğu altyapının dökümü. Kaynak: koddaki varsayılanlar ve
`envs/frankfurt-baseline`. Local Zone'a geçişte neyin değişeceğini görmek için
referans.

## Özet

| Konu | Bugünkü durum |
| --- | --- |
| Kurulum yöntemi | Tamamı Terraform. Kök modül `main/`, ortamlar `envs/<ortam>/`, state S3'te (`bootstrap/`). |
| Bölge | `eu-central-1` (Frankfurt), 2 AZ |
| Uygulama | ECS Fargate, servis başına 2 task (autoscaling 2–6, CPU %70) |
| İmaj | ECR `<name>-wordpress`; CodeBuild, wordpress-shop-demo reposundaki Dockerfile'dan üretir |
| Veritabanı | RDS MariaDB 11.8, `db.t3.micro`, gp3, şifreli, TLS zorunlu |
| Object cache | ElastiCache Memcached, 2 node, cross-AZ; baseline'da varsayılan kapalı (`enable_elasticache`), LZ ile aynı uygulama mimarisi |
| Medya | S3 (OAC ile yalnızca CloudFront okur), WP Offload Media Lite yazar |
| `wp-content` | Baseline'da EFS yok: kod imajda, medya S3'te. EFS opsiyonel (`enable_efs`). |
| CDN / WAF | CloudFront + WAF (us-east-1), ALB yalnızca CloudFront prefix list'inden erişilebilir |
| Secret'lar | SSM Parameter Store SecureString (DB parolası, 8 WordPress salt'ı) |
| Loglar | `awslogs` → CloudWatch Logs `eu-central-1`, 30 gün |
| CI/CD | CodePipeline + CodeBuild (CodeStar connection), push'ta build + ECS deploy |

## Ağ

- VPC `10.0.0.0/16`. Her AZ'de üç subnet: public (`10.0.1-4.0/24`), app
  (`10.0.10-13.0/24`), data (`10.0.20-23.0/24`).
- AZ başına bir NAT gateway; app subnet'leri kendi AZ'sindeki NAT'a çıkar.
- Data subnet'lerinin internete rotası yok.
- Opsiyonel Pritunl VPN (`enable_vpn`), ilk AZ'nin public subnet'inde, yönetim
  erişimi için. Baseline'da kapalı. Faz 3'teki on-prem bağlantısı bu değil.

## ECS

| Ayar | Değer |
| --- | --- |
| Cluster | `<name>-cluster`, Container Insights açık, kapasite `FARGATE` (`FARGATE_SPOT` tanımlı, kullanılmıyor) |
| Task | 512 CPU / 1024 MiB, `awsvpc`, konteyner adı `wordpress`, port 80 |
| Servis | `launch_type = FARGATE`, AZ rebalancing açık, deploy %100–200 |
| Sağlık kontrolü | ALB → `/health.php` (WordPress yüklenmez) |
| ECS Exec | Baseline'da açık (seed kiti için); oturumlar `/ecs/<name>-exec` log grubuna yazılır |
| Task role | Medya bucket'ına okuma/yazma; EFS açıksa access point'lere mount |
| Execution role | ECR çekme, CloudWatch'a log, SSM'den DB parolası ve salt'lar |

Task'a verilen ortam değişkenleri: `WORDPRESS_DB_HOST/NAME/USER`,
`MEMCACHED_HOST` (bütün node'lar), `WP_HOME` (CloudFront adresi),
`WORDPRESS_DISALLOW_FILE_MODS`, `WP_S3_*` (offload açıksa). Secret'lar:
`WORDPRESS_DB_PASSWORD` ve `WORDPRESS_{AUTH,SECURE_AUTH,LOGGED_IN,NONCE}_{KEY,SALT}`.

## Veritabanı

- RDS MariaDB `11.8.8`, 20 GB gp3 (100 GB'a kadar otomatik büyür), şifreli,
  public değil.
- Multi-AZ varsayılan kapalı. Read replica baseline'da varsayılan kapalı
  (`create_read_replica`): imaj yalnızca writer endpoint'i kullanıyor
  (HyperDB/LudicrousDB yok), replica okuma yükü almıyordu.
- Yedek: RDS otomatik yedek 7 gün + AWS Backup günlük, 30 gün saklama.
  Snapshot'lar ve recovery point'ler etiketleri taşır (`copy_tags_to_snapshot`,
  `recovery_point_tags`).
- Bağlantı TLS'li, sunucu sertifikası doğrulanmıyor (imajda RDS CA bundle'ı yok).

## İmaj (wordpress-shop-demo)

- Taban: `wordpress:7.0-php8.3-apache`, PECL memcached, stunnel, WP-CLI.
- Gömülü eklenti/tema: WooCommerce, WP Offload Media Lite, Storefront,
  `shopdemo` alt teması, Memcached Redux drop-in'i, mu-plugin'ler (offline
  ödeme, TCKN alanı, demo uyarısı).
- Eklenti sürümleri sabit değil: Dockerfile build anında `latest-stable` indirir.
- Seed kiti `/usr/src/shop-seed/` altında; ECS Exec ile çalışır, dışarıya
  istek atmaz.
- `tr_TR` dil paketleri imajda; seed kiti site dilini Türkçe yapar.

## Kişisel veri nerede

Seed kiti ve gerçek checkout'un ürettiği kişisel veri (ad, adres, telefon,
e-posta, TCKN) WordPress veritabanında. Bu yüzden `data-class=personal`
etiketli kaynaklar:

| Kaynak | Neden |
| --- | --- |
| RDS primary + replica, snapshot'lar, AWS Backup recovery point'leri | Müşteri ve sipariş tabloları |
| ElastiCache | Object cache'te kullanıcı ve sipariş nesneleri |
| CloudWatch log grupları | Apache erişim loglarında istemci IP'si, ECS Exec oturumları |
| EFS (açıksa) | `uploads/wc-logs`, `woocommerce_uploads` |

Medya bucket'ı `data-class=non-personal` (ürün görselleri). Hepsine
`data-residency=tr` yazılır; baseline'da bunların hepsinin Frankfurt'ta olması,
Residency Guard'ın ilk raporunda bulgu olarak görünmeleri beklenir.

Etiketsiz olup kişisel veri taşıyabilecek yerler: SSM parametreleri (secret,
kişisel veri değil), ECR imajı (kişisel veri yok).

## Local Zone'a geçişte etkilenecekler

| Bileşen | Bugün | İstanbul LZ'de |
| --- | --- | --- |
| ECS | Fargate | Fargate yok → EC2 capacity provider (ADR-002) |
| RDS | MariaDB, Frankfurt | RDS yok → EC2 + EBS gp3 üzerinde MariaDB (ADR-006) |
| ElastiCache | Frankfurt | LZ'de yok; ya Frankfurt'ta kalır ya EC2'de memcached / kapatılır |
| EFS | Baseline'da kullanılmıyor | Yok; değişiklik gerekmez |
| Medya S3 | Standart bucket, Frankfurt | LZ'de S3 One Zone-IA; offload eklentisi uyumu doğrulanacak |
| ALB | 2 AZ subnet'i | LZ subnet'lerinde ayrı ALB; WAF entegrasyonu yok |
| WAF | Zaten CloudFront'ta | Değişmez (ADR-005) |
| Loglar | CloudWatch, Frankfurt | Faz 5'te bulgu, Faz 6'da karar (ADR-003) |
| AWS Backup | Frankfurt vault | Kopyalar Frankfurt'ta kalır → yerel EBS snapshot politikası |
| NAT | AZ başına | LZ subnet'inin çıkışı nereden olacak not edilecek (Faz 4.1) |

## Açık konular

- ~~**Dil paketleri kalıcı değil.**~~ Çözüldü: `tr_TR` çekirdek, WooCommerce
  ve Storefront çevirileri artık imaja gömülü (wordpress-shop-demo,
  `docker/install-translations.sh`); çalışma anında wordpress.org'a gidilmiyor.
- **Eklenti sürümleri sabit değil.** Aynı commit'ten farklı günlerde farklı
  WooCommerce sürümü çıkabilir; ölçüm turları arasında karşılaştırmayı bozar.
- ~~**Read replica boşta.**~~ Baseline'da varsayılan kapatıldı; açılırsa
  imaja replica desteği eklenmeli.
- **`WORDPRESS_CONFIG_EXTRA`** ECS modülünde hâlâ veriliyor ama imajın kendi
  `wp-config.php`'si bunu okumuyor; aynı işi (HTTPS algılama, DB TLS) kendisi
  yapıyor. Stok `wordpress` imajıyla çalışılırsa gerekli olduğu için duruyor.
- **ALB / CloudFront / WAF erişim logları ve VPC Flow Logs kapalı.** Faz 5'teki
  egress ölçümü için Flow Logs ve Route 53 Resolver query logging açılacak.
- **CI'da Terraform kontrolü yok.** fmt/validate/tflint/conftest Faz 7'de.
