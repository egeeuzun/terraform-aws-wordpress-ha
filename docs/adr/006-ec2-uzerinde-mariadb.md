# ADR-006: Local Zone'da RDS yerine EC2 üzerinde MariaDB

- **Durum:** Kabul edildi
- **Tarih:** 2026-10-27

## Bağlam

WooCommerce müşteri, sipariş ve TCKN verisini WordPress veritabanında tutuyor;
veri yerelliği hedefinin merkezi bu veritabanı. RDS İstanbul Local Zone'da yok.
Local Zone'da EC2, EBS (gp3) ve EBS Local Snapshots var.

## Karar

MariaDB'yi Local Zone'daki tek bir EC2 instance'ında çalıştırıyoruz
(`modules/db-ec2-mariadb`):

- **Sürüm:** Ubuntu 26.04 ile gelen MariaDB 11.8. Frankfurt'taki RDS de 11.8;
  aynı seri olduğu için dump'lar collation farkına takılmadan taşınır.
- **Veri ayrı diskte:** `/var/lib/mysql` ayrı, şifreli bir gp3 EBS diski.
  Instance değiştirilebilir; yenisi diski takar, veriyi bulur, aynı sabit özel
  IP ile açılır. WordPress'in `DB_HOST`'u değişmez.
- **Erişim:** Yalnızca ECS task'larının security group'undan 3306. Bağlantılar
  TLS zorunlu (`require_secure_transport`), self-signed sertifika; imaj
  sertifikayı zaten doğrulamıyor (Frankfurt'ta da öyle).
- **Parola:** Terraform üretir, SSM'de durur; instance ilk açılışta kendi
  rolüyle okur. user_data'da parola yok.
- **Yedek:** Data Lifecycle Manager her gece 00:00 UTC'de diskin snapshot'ını
  **Local Zone'un içinde** alır (`location = LOCAL_ZONE`), 7 tane saklar.
  Varsayılan (`CLOUD`) snapshot'ı Frankfurt'a yazardı.
- **Bakım:** Session Manager; SSH portu yok.

## Sonuçlar

- **Tek nokta arızası.** Instance ya da Local Zone düşerse mağaza düşer. RDS
  Multi-AZ'nin otomatik failover'ı yok. Local Zone tek lokasyon olduğu için
  ikinci bir zone'a replika, veriyi Türkiye dışına çıkarmadan mümkün değil
  (ADR-004'te ele alınacak).
- **Snapshot'lar crash-consistent.** MariaDB çalışırken alınıyor; InnoDB açılışta
  toparlar ama işlem ortasındaki veri tutarlılığı garanti değil. Uygulama
  seviyesinde tutarlı yedek için gece `mysqldump` eklenmeli (Local Zone'daki bir
  bucket'a; açık iş).
- **Point-in-time restore yok.** En kötü durumda son gece yedeğine dönülür.
- **Sorumluluk bizde:** güvenlik güncellemeleri, disk dolması, izleme ve geri
  yükleme testi. Geri yükleme en az bir kez denenmeden yedek sayılmaz.
- **İlk açılış dışarıya bağlı:** paketler Ubuntu arşivinden ve snap'ten NAT
  üzerinden iner. NAT parent AZ'deyse bu trafik Frankfurt'tan çıkar.
