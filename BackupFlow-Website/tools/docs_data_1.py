# -*- coding: utf-8 -*-
"""Localized documentation content (Part 1: en, tr, de, fr, es, ru) for BackupFlow v4.7."""

DOCS_PART_1 = {
    "en": {
        "title": "BackupFlow Help & Documentation",
        "description": "Complete guide to BackupFlow for iOS: Backup Hub, FTP/SFTP/WebDAV setup, Photo Library and Files backup, scheduling, deletion policies, checksum verification, and troubleshooting.",
        "h1": "BackupFlow Help",
        "lead": "BackupFlow backs up your iPhone photos, videos, and files directly to your own server — a NAS, home server, or personal cloud — over FTP, SFTP, or WebDAV. No subscription and no third-party cloud.",
        "toc_title": "On this page",
        "sections": [
            (
                "what-you-need",
                "1. What you need",
                """<ul>
<li><b>A compatible server</b>: Any NAS (Synology, QNAP, TrueNAS, Unraid), home server (Linux, macOS, Windows, Raspberry Pi), or personal cloud (Nextcloud, ownCloud, WebDAV storage) that supports <b>FTP</b>, <b>SFTP (SSH)</b>, or <b>WebDAV (HTTP/HTTPS)</b>.</li>
<li><b>Connection details</b>: Your server address (IP, hostname, or full WebDAV URL), port number (defaults: FTP <b>21</b>, SFTP <b>22</b>, WebDAV <b>443</b> or <b>80</b>), and login credentials (<b>Username</b> and <b>Password</b>, or <b>Anonymous Login</b> for FTP).</li>
<li><b>iOS permissions</b>:
    <ul>
        <li><b>Photos</b>: Allow full photo library access when backing up photos or videos.</li>
        <li><b>Local Network</b>: If your server is on your home/office Wi-Fi, tap <b>Allow</b> when iOS asks for local network access.</li>
        <li><b>Notifications</b>: Recommended so BackupFlow can alert you when scheduled backups run or finish.</li>
    </ul>
</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. Backup Hub overview",
                """<p>When you open BackupFlow, the <b>Backup Hub</b> gives you a real-time overview of your backup system:</p>
<ul>
<li><b>Status Banner</b>: Displays your <b>Last sync</b> timestamp, the <b>Next Task</b> time and task name, your current protection status (<b>Safe &amp; synced</b>), active server address, and a green <b>Play (▶)</b> button to launch a backup immediately.</li>
<li><b>Backup health</b>: Tracks your overall reliability with <b>Success</b> rate (percentage and completed runs), consecutive <b>Failures</b>, last successful backup date, and <b>Average duration</b>.</li>
<li><b>Saved servers</b>: Shows color-coded cards for all your configured <b>FTP</b>, <b>SFTP</b>, and <b>WebDAV</b> backup tasks, including destination path and last run time. Tap the <b>Edit (✏️)</b> icon to modify a task, the <b>Delete (🗑️)</b> icon to remove it, or tap anywhere on a card to open <b>Task Details</b>.</li>
<li><b>Bottom Navigation &amp; Settings</b>: Use the three buttons at the bottom of the screen to <b>Run/Sync (🔄)</b>, open <b>Backup History (🕒)</b>, or create a <b>New Backup (+)</b>. Tap the <b>gear icon (⚙️)</b> at the top right to open <b>Settings</b>.</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. Create a new backup",
                """<p>Tap the <b>+</b> button at the bottom of the <b>Backup Hub</b> (or tap <b>Add</b> next to <b>Saved servers</b>) to open the <b>New Backup</b> screen:</p>
<ol>
<li><b>Source</b>:
    <ul>
        <li>Select <b>Photo Library</b> to back up media from the iOS Photos app (choose <b>Photos Only</b>, <b>Videos Only</b>, or <b>Photos and Videos</b>), or</li>
        <li>Select <b>Select Folder</b> to pick any folder from the iOS <b>Files</b> app (On My iPhone, iCloud Drive, or external drives).</li>
    </ul>
</li>
<li><b>Target Type</b>:
    <ul>
        <li>Choose <b>FTP</b>, <b>SFTP</b>, or <b>WebDAV</b> from the segmented bar.</li>
        <li>Enter your <b>Server Address</b> (for WebDAV, enter the full server URL) and <b>Port</b> (e.g., <b>21</b> for FTP, <b>22</b> for SFTP, <b>443</b> for HTTPS WebDAV).</li>
        <li>Enter your <b>Username</b> and <b>Password</b> (or turn on <b>Anonymous Login</b> if your FTP server allows anonymous access).</li>
        <li>Enter the destination path on the server (such as <code>/backups/iphone</code> or <code>/remote.php/dav/files/username/</code> for Nextcloud).</li>
        <li>Tap <b>Test Connection</b> to verify your server credentials, then optionally tap <b>Browse remote folder</b> to navigate and pick a folder directly on the server.</li>
    </ul>
</li>
<li><b>Scheduling</b>: Choose when the task should run (<b>Manual</b>, <b>Daily</b>, <b>Weekly</b>, <b>Monthly</b>, or <b>Interval</b>) and pick a time under <b>Select Time</b>.</li>
<li><b>Backup behavior</b>: Configure your <b>Deletion policy</b>, <b>Checksum</b> verification, and network/power conditions, then save the task.</li>
</ol>
<p>After your first backup completes, BackupFlow tracks transferred files and uploads <b>only new or changed files</b> on future runs, making subsequent backups much faster.</p>""",
            ),
            (
                "task-details",
                "4. Task Details & management",
                """<p>Tap any card under <b>Saved servers</b> on the <b>Backup Hub</b> to open <b>Task Details</b>:</p>
<ul>
<li><b>General</b>: Review the task's <b>Source</b> (e.g., Photo Library or Folder), current <b>Status</b> (such as <b>Ready</b>), <b>Schedule</b> mode, <b>Deletion policy</b>, and <b>Checksum</b> setting.</li>
<li><b>Server</b>: Inspect the configured <b>Server</b> address, <b>Port</b>, and <b>User</b> account.</li>
<li><b>Recent Backups</b>: See the latest backup sessions for this specific task, including date and time, completion badge, number of files transferred, total size, and duration.</li>
<li>Tap <b>Edit</b> at the top left to update any setting for this task, or tap <b>Close</b> to return to the <b>Backup Hub</b>.</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. Scheduling & run conditions",
                """<p>Under <b>Scheduling</b> in the task configuration, you can choose from five modes:</p>
<ul>
<li><b>Manual</b>: Runs only when you start it manually from the <b>Backup Hub</b>.</li>
<li><b>Daily</b>: Runs once every day at the hour and minute set in <b>Select Time</b>.</li>
<li><b>Weekly</b>: Runs once a week at your chosen day and time.</li>
<li><b>Monthly</b>: Runs once a month at your chosen schedule.</li>
<li><b>Interval</b>: Runs repeatedly at a regular hour interval.</li>
</ul>
<p>Under <b>Backup behavior</b>, you can restrict when automatic backups are allowed to run:</p>
<ul>
<li><b>Require Wi-Fi</b>: Ensures backups never use cellular/mobile data.</li>
<li><b>Require external power</b>: Runs only while your iPhone is connected to a charger.</li>
<li><b>Use allowed time window</b>: Restricts scheduled runs to a specific time range (for example, overnight).</li>
<li><b>Minimum Battery Level</b> (configured in <b>Settings › Battery Settings</b>): Automatically skips scheduled runs when your battery is below the threshold.</li>
</ul>
<p>If a condition is not met at the scheduled time, the backup waits safely and runs as soon as all conditions are satisfied.</p>""",
            ),
            (
                "deleted-files",
                "6. Deletion policy, Checksum & iCloud",
                """<p>In the <b>Backup behavior</b> section of every task, you control how deleted files and file verification are handled:</p>
<dl>
<dt>Deletion policy › Append-only</dt>
<dd>Files are only added or updated on the server; nothing is ever deleted from your server. <b>Recommended</b> if you want to delete photos/videos from your iPhone to free up space while keeping them permanently on your server.</dd>
<dt>Deletion policy › Mirror</dt>
<dd>Keeps the destination folder on your server an exact mirror of your iPhone source. Files you delete on your iPhone are also deleted from the server during the next sync.</dd>
<dt>Deletion policy › Archive delete</dt>
<dd>No files are permanently lost. Files removed on your iPhone are moved into a dated <b>.backupflow_archive</b> folder on the server.</dd>
<dt>Checksum</dt>
<dd>When enabled, BackupFlow verifies file integrity (checksum/size verification) after uploading to ensure every file arrived on the server intact. Set to <b>Off</b> for maximum transfer speed.</dd>
</dl>
<p class="note"><b>Important tip:</b> If you use <b>iCloud Photos</b> with "Optimize iPhone Storage", enable <b>Download iCloud items if needed</b> in the photo source options so BackupFlow can fetch full-resolution originals from iCloud before uploading them to your server.</p>""",
            ),
            (
                "background",
                "7. Backing up in the background",
                """<p>BackupFlow integrates with iOS <b>BGTaskScheduler</b> to run scheduled backups automatically. Because iOS controls background execution timing based on battery, charging state, and device usage patterns, a scheduled task may start slightly after the exact minute selected.</p>
<ul>
<li>When a scheduled backup is ready, BackupFlow either runs it automatically in the background or sends a notification so you can tap to start immediately.</li>
<li>If iOS pauses a background transfer before completion, simply open BackupFlow — the task resumes automatically and skips files that were already uploaded.</li>
<li><b>Tip for your first backup:</b> If you have thousands of photos or large 4K videos, keep BackupFlow open on screen with your iPhone connected to Wi-Fi and a charger for the initial full transfer.</li>
</ul>""",
            ),
            (
                "history",
                "8. Backup History",
                """<p>Tap the <b>History (🕒)</b> button in the middle of the bottom bar on the <b>Backup Hub</b> to open <b>Backup History</b>:</p>
<ul>
<li><b>Summary Cards</b>: At the top, view total <b>Completed</b> runs, <b>Failed</b> runs, and cumulative data <b>Transferred</b> (in MB/GB).</li>
<li><b>Detailed Run Logs</b>: Each card displays the task name, date and time, status badge (<b>Completed</b> or <b>Failed</b>), <b>Files</b> count (e.g., <code>1236/1236</code>), data <b>Transferred</b>, and <b>Duration</b>.</li>
<li><b>Clear History</b>: Tap the <b>trash icon (🗑️)</b> at the top right of the <b>Backup History</b> screen to clear past logs.</li>
</ul>""",
            ),
            (
                "settings",
                "9. App Settings",
                """<p>Tap the <b>gear icon (⚙️)</b> at the top right of the <b>Backup Hub</b> to open <b>Settings</b>:</p>
<ul>
<li><b>History Retention (Days)</b>: Choose how long backup history logs are stored on your device (e.g., <b>30 days</b>).</li>
<li><b>Require External Power</b>: Global setting requiring the iPhone to be charging for backups to run.</li>
<li><b>Battery Settings</b>: Configure minimum battery level thresholds and power-saving rules.</li>
<li><b>Language</b>: Switch the app's interface language at any time across all 12 supported languages (English, Türkçe, Deutsch, Français, Español, Русский, العربية, 简体中文, 한국어, 日本語, Português, हिन्दी).</li>
<li><b>About</b>: View the installed <b>Version</b>, tap <b>Rate App</b> to leave a review on the App Store, or tap <b>Contact Support</b>.</li>
<li><b>Reset All Data</b>: Removes all configured tasks, backup history, and saved server credentials from your iPhone. Your files on your remote servers are never touched.</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. Troubleshooting",
                """<dl>
<dt>I can't connect to my server.</dt>
<dd>Double-check your <b>Server Address</b>, <b>Port</b> (FTP: 21, SFTP: 22, WebDAV: 443/80), <b>Username</b>, and <b>Password</b>. For Nextcloud/ownCloud WebDAV, make sure the path includes <code>/remote.php/dav/files/your-username/</code>. If your server is on your local network, verify your iPhone is on the same Wi-Fi and that local network permission is enabled in <b>iPhone Settings › Privacy &amp; Security › Local Network › BackupFlow</b>.</dd>
<dt>A scheduled backup didn't run.</dt>
<dd>Check the task's <b>Backup behavior</b> conditions (<b>Require Wi-Fi</b>, <b>Require external power</b>, <b>Use allowed time window</b>) and <b>Settings › Battery Settings</b>. Also make sure Background App Refresh and Notifications are enabled for BackupFlow in iOS Settings.</dd>
<dt>Some photos or videos were not backed up.</dt>
<dd>Ensure BackupFlow has <b>Full Access</b> to your Photo Library in <b>iPhone Settings › Privacy &amp; Security › Photos</b>, and turn on <b>Download iCloud items if needed</b> if you use iCloud Photos.</dd>
<dt>Files were removed from my server after deleting them on my iPhone.</dt>
<dd>Your task's <b>Deletion policy</b> is set to <b>Mirror</b>. Edit the task and change <b>Deletion policy</b> to <b>Append-only</b> or <b>Archive delete</b>.</dd>
<dt>I see an SFTP host key security warning.</dt>
<dd>BackupFlow remembers your SFTP server's SSH fingerprint on first connection and warns you if it changes. This is normal if you reinstalled or replaced the server; otherwise verify with your server administrator before accepting.</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. Privacy & security",
                """<p>BackupFlow is built with a strict <b>local-first privacy</b> architecture: your photos, videos, and files are transferred directly from your iPhone to your own server. BackupFlow operates no intermediate cloud servers, never accesses your files, and includes no analytics, tracking, or advertising SDKs.</p>
<p>Server passwords are encrypted in the <b>iOS Keychain</b> on your device. Read our full <a href="../../privacy-policy.html">Privacy Policy</a> for complete details.</p>""",
            ),
            (
                "help",
                "12. Need help?",
                """<p>Open <b>Settings › Contact Support</b> inside BackupFlow (or email <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>). The app automatically includes your app version and iPhone model so we can help you quickly.</p>""",
            ),
        ],
    },

    "tr": {
        "title": "BackupFlow Yardım ve Dokümantasyon",
        "description": "iOS için BackupFlow kullanım kılavuzu: Yedekleme Merkezi, FTP/SFTP/WebDAV kurulumu, Fotoğraf Galerisi ve Dosyalar yedekleme, zamanlama, silme politikaları ve sorun giderme.",
        "h1": "BackupFlow Yardım",
        "lead": "BackupFlow, iPhone'unuzdaki fotoğraf, video ve dosyaları FTP, SFTP veya WebDAV üzerinden doğrudan kendi sunucunuza (NAS, ev sunucusu veya kişisel bulut) yedekler. Abonelik yok, üçüncü taraf bulut yok.",
        "toc_title": "Bu sayfada",
        "sections": [
            (
                "what-you-need",
                "1. Neye ihtiyacınız var?",
                """<ul>
<li><b>Uyumlu bir sunucu</b>: <b>FTP</b>, <b>SFTP (SSH)</b> veya <b>WebDAV (HTTP/HTTPS)</b> destekleyen herhangi bir NAS cihazı (Synology, QNAP, TrueNAS, Unraid), ev sunucusu (Linux, macOS, Windows, Raspberry Pi) veya kişisel bulut (Nextcloud, ownCloud, WebDAV depolama).</li>
<li><b>Bağlantı bilgileri</b>: Sunucu adresiniz (IP, alan adı veya tam WebDAV URL'si), port numarası (varsayılan: FTP <b>21</b>, SFTP <b>22</b>, WebDAV <b>443</b> veya <b>80</b>) ve giriş bilgileriniz (<b>Kullanıcı Adı</b> ve <b>Şifre</b> ya da FTP için <b>Anonim Giriş</b>).</li>
<li><b>iOS izinleri</b>:
    <ul>
        <li><b>Fotoğraflar</b>: Fotoğraf ve videoları yedeklemek için tam galeri erişimine izin verin.</li>
        <li><b>Yerel Ağ</b>: Sunucunuz ev/ofis Wi-Fi ağınızdaysa iOS yerel ağ erişimi istediğinde <b>İzin Ver</b>'e dokunun.</li>
        <li><b>Bildirimler</b>: Zamanlanmış yedeklemeler başladığında veya tamamlandığında haberdar olmak için bildirimlere izin verin.</li>
    </ul>
</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. Yedekleme Merkezi genel bakış",
                """<p>BackupFlow'u açtığınızda karşınıza çıkan <b>Yedekleme Merkezi</b>, yedekleme sisteminizin anlık durumunu tek ekranda sunar:</p>
<ul>
<li><b>Durum Kartı</b>: <b>Son eşitleme</b> zamanını, <b>Sonraki Görev</b> saatini ve adını, genel koruma durumunuzu (<b>Güvende ve eşitlenmiş</b>), aktif sunucu adresini ve yedeği anında başlatmak için yeşil <b>Oynat (▶)</b> butonunu gösterir.</li>
<li><b>Yedekleme sağlığı</b>: <b>Başarı</b> oranınızı (yüzde ve toplam çalışma sayısı), üst üste oluşan <b>Hatalar</b> sayısını, son başarılı yedekleme tarihini ve <b>Ortalama süre</b> bilgisini takip eder.</li>
<li><b>Kayıtlı sunucular</b>: Yapılandırdığınız tüm <b>FTP</b>, <b>SFTP</b> ve <b>WebDAV</b> görevlerini hedef klasör ve son kullanım tarihiyle birlikte renkli kartlar halinde listeler. Görevi düzenlemek için <b>Düzenle (✏️)</b> simgesine, silmek için <b>Sil (🗑️)</b> simgesine, detayları görmek içinse kartın üzerine dokunabilirsiniz.</li>
<li><b>Alt Menü ve Ayarlar</b>: Ekranın altındaki üç yuvarlak buton ile <b>Eşitle/Çalıştır (🔄)</b> işlemini başlatabilir, <b>Yedek Geçmişi (🕒)</b> ekranını açabilir veya <b>Yeni Yedekleme (+)</b> oluşturabilirsiniz. Sağ üstteki <b>dişli çark (⚙️)</b> simgesi ise <b>Ayarlar</b> ekranını açar.</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. Yeni yedekleme oluşturma",
                """<p><b>Yedekleme Merkezi</b>'nin altındaki <b>+</b> butonuna (veya <b>Kayıtlı sunucular</b> yanındaki <b>Ekle</b>'ye) dokunarak <b>Yeni Yedekleme</b> ekranını açın:</p>
<ol>
<li><b>Kaynak</b>:
    <ul>
        <li>iOS Fotoğraflar uygulamasındaki medyaları yedeklemek için <b>Fotoğraf Galerisi</b>'ni seçin (<b>Yalnızca Fotoğraflar</b>, <b>Yalnızca Videolar</b> veya <b>Fotoğraflar ve Videolar</b>), ya da</li>
        <li>iOS <b>Dosyalar</b> uygulamasındaki herhangi bir klasörü yedeklemek için <b>Klasör Seç</b>'e dokunun.</li>
    </ul>
</li>
<li><b>Hedef Tipi</b>:
    <ul>
        <li>Üstteki sekmeden <b>FTP</b>, <b>SFTP</b> veya <b>WebDAV</b> protokolünü seçin.</li>
        <li><b>Sunucu Adresi</b> (WebDAV için tam URL) ve <b>Port</b> bilgisini girin (FTP: <b>21</b>, SFTP: <b>22</b>, WebDAV: <b>443</b>/<b>80</b>).</li>
        <li><b>Kullanıcı Adı</b> ve <b>Şifre</b> bilgilerinizi yazın (FTP sunucunuz destekliyorsa <b>Anonim Giriş</b> seçeneğini de açabilirsiniz).</li>
        <li>Sunucu üzerindeki hedef klasör yolunu girin (ör. <code>/archive</code> veya Nextcloud için <code>/remote.php/dav/files/kullanici/</code>).</li>
        <li>Bilgileri doğrulamak için <b>Bağlantıyı Test Et</b>'e dokunun; dilerseniz <b>Uzak klasöre göz at</b> butonuna dokunarak sunucudaki klasörü doğrudan seçin.</li>
    </ul>
</li>
<li><b>Zamanlama</b>: Görevin çalışma sıklığını seçin (<b>Manuel</b>, <b>Günlük</b>, <b>Haftalık</b>, <b>Aylık</b> veya <b>Aralık</b>) ve <b>Saat seç</b> kısmından saati belirleyin.</li>
<li><b>Yedekleme davranışı</b>: <b>Silme politikası</b>, <b>Sağlama toplamı</b> ve çalışma koşullarını ayarlayıp görevi kaydedin.</li>
</ol>
<p>İlk tam yedeklemeden sonra BackupFlow yalnızca <b>yeni eklenen veya değişen dosyaları</b> aktarır; böylece sonraki yedeklemeler çok kısa sürede tamamlanır.</p>""",
            ),
            (
                "task-details",
                "4. Görev Detayları ve yönetim",
                """<p><b>Yedekleme Merkezi</b>'nde <b>Kayıtlı sunucular</b> altındaki herhangi bir göreve dokunduğunuzda <b>Görev Detayları</b> ekranı açılır:</p>
<ul>
<li><b>Genel</b>: Görevin <b>Kaynak</b> bilgisini, güncel <b>Durum</b> (ör. <b>Hazır</b>), <b>Zamanlama</b>, <b>Silme politikası</b> ve <b>Sağlama toplamı</b> ayarlarını görüntüler.</li>
<li><b>Sunucu</b>: Bağlı olunan <b>Sunucu</b> adresini, <b>Port</b> numarasını ve <b>Kullanıcı</b> adını gösterir.</li>
<li><b>Son Yedeklemeler</b>: Bu göreve ait son yedekleme çalışmalarını tarih/saat, durum (<b>Tamamlandı</b>), aktarılan dosya sayısı, boyut ve süre bilgileriyle listeler.</li>
<li>Görevi güncellemek için sol üstteki <b>Düzenle</b> butonuna, çıkmak için sağ üstteki <b>Kapat</b> butonuna dokunun.</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. Zamanlama ve çalışma koşulları",
                """<p>Görev oluştururken veya düzenlerken <b>Zamanlama</b> bölümünde beş seçenek bulunur:</p>
<ul>
<li><b>Manuel</b>: Yalnızca siz başlattığınızda çalışır.</li>
<li><b>Günlük</b>: Her gün <b>Saat seç</b> alanında belirlediğiniz saat ve dakikada çalışır.</li>
<li><b>Haftalık</b>: Haftada bir kez belirlediğiniz gün ve saatte çalışır.</li>
<li><b>Aylık</b>: Ayda bir kez otomatik çalışır.</li>
<li><b>Aralık</b>: Belirlediğiniz saat aralığında periyodik olarak tekrarlanır.</li>
</ul>
<p><b>Yedekleme davranışı</b> altında otomatik yedeklemenin hangi koşullarda çalışacağını sınırlandırabilirsiniz:</p>
<ul>
<li><b>Wi-Fi gerekli</b>: Hücresel/mobil verinin kullanılmasını tamamen engeller.</li>
<li><b>Harici güç gerekli</b>: Yalnızca iPhone şarja takılıyken yedekleme yapar.</li>
<li><b>İzinli saat aralığını kullan</b>: Otomatik yedeklemeyi yalnızca belirlediğiniz saat diliminde (örneğin gece saatlerinde) çalıştırır.</li>
<li><b>Minimum Pil Seviyesi</b> (<b>Ayarlar › Pil Ayarları</b>): Pil seviyesi belirlediğiniz eşiğin altındaysa yedeklemeyi erteleyerek pilinizi korur.</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. Silme politikası, Sağlama toplamı ve iCloud",
                """<p><b>Yedekleme davranışı</b> bölümünde iPhone'unuzdan sildiğiniz dosyaların sunucuda nasıl işleneceğini ve dosya doğrulamasını seçebilirsiniz:</p>
<dl>
<dt>Silme politikası › Sadece ekle</dt>
<dd>Sunucuya yalnızca yeni ve güncel dosyalar eklenir; sunucudan hiçbir dosya silinmez. Yedekleme sonrası iPhone'unuzda yer açmak için fotoğraf/video silmeyi planlıyorsanız <b>kesinlikle bu modu kullanın</b>.</dd>
<dt>Silme politikası › Ayna</dt>
<dd>Sunucudaki klasörü iPhone'daki kaynağın birebir kopyası tutar. iPhone'dan sildiğiniz dosyalar bir sonraki eşitlemede sunucudan da silinir.</dd>
<dt>Silme politikası › Arşivli silme</dt>
<dd>Hiçbir dosya kalıcı olarak silinmez. iPhone'dan kaldırılan dosyalar sunucuda tarihli <b>.backupflow_archive</b> klasörüne taşınır.</dd>
<dt>Sağlama toplamı (Checksum)</dt>
<dd>Açık olduğunda, yüklenen her dosyanın sunucuya bozulmadan ve eksiksiz ulaştığını doğrular. Maksimum hız için <b>Kapalı</b> tutabilirsiniz.</dd>
</dl>
<p class="note"><b>Önemli ipucu:</b> iCloud Fotoğrafları ve "iPhone'da En İyi Saklama" kullanıyorsanız, yalnızca iCloud'da bulunan orijinal fotoğraf ve videoların da yedeklenmesi için kaynak ayarlarında <b>Gerekirse iCloud öğelerini indir</b> seçeneğini etkinleştirin.</p>""",
            ),
            (
                "background",
                "7. Arka planda yedekleme",
                """<p>BackupFlow, zamanlanmış görevleri çalıştırmak için iOS <b>BGTaskScheduler</b> altyapısını kullanır. iOS arka plan çalışma zamanlarını pil durumu, şarj ve cihaz kullanım alışkanlıklarına göre yönettiği için zamanlanmış yedekler seçilen dakikadan biraz sonra başlayabilir.</p>
<ul>
<li>Zamanı geldiğinde BackupFlow yedeği arka planda başlatır veya tek dokunuşla başlatabilmeniz için bir bildirim gönderir.</li>
<li>iOS arka plan aktarımını bitmeden duraklatırsa uygulamayı açmanız yeterlidir; yedekleme kaldığı yerden devam eder ve daha önce aktarılan dosyalar tekrar gönderilmez.</li>
<li><b>İlk yedekleme için öneri:</b> Çok sayıda fotoğraf veya büyük videolar içeren ilk tam yedeklemede iPhone'unuzu Wi-Fi'a ve şarja bağlı tutarak uygulamayı açık bırakmanız önerilir.</li>
</ul>""",
            ),
            (
                "history",
                "8. Yedek Geçmişi",
                """<p><b>Yedekleme Merkezi</b>'nin alt barındaki ortada bulunan <b>Geçmiş (🕒)</b> butonuna dokunarak <b>Yedek Geçmişi</b> ekranını açabilirsiniz:</p>
<ul>
<li><b>Özet Kartları</b>: Üst kısımda toplam <b>Tamamlanan</b>, <b>Başarısız</b> görev sayılarını ve bugüne kadar toplam <b>Aktarılan</b> veri miktarını (MB/GB) görebilirsiniz.</li>
<li><b>Detaylı Kayıtlar</b>: Her yedekleme kartında görev adı, tarih ve saat, durum etiketi (<b>Tamamlandı</b>), <b>Dosyalar</b> (ör. <code>1236/1236</code>), <b>Aktarılan</b> boyut ve <b>Süre</b> yer alır.</li>
<li><b>Geçmişi Temizleme</b>: Sağ üstteki <b>çöp kutusu (🗑️)</b> simgesine dokunarak geçmiş kayıtlarını temizleyebilirsiniz.</li>
</ul>""",
            ),
            (
                "settings",
                "9. Uygulama Ayarları",
                """<p><b>Yedekleme Merkezi</b>'nin sağ üst köşesindeki <b>dişli çark (⚙️)</b> simgesine dokunarak <b>Ayarlar</b> ekranına ulaşabilirsiniz:</p>
<ul>
<li><b>Geçmiş Saklama (Gün)</b>: Yedekleme kayıtlarının cihazda kaç gün saklanacağını belirleyin (ör. <b>30 gün</b>).</li>
<li><b>Harici Güç Gerektir</b>: Yedeklemelerin yalnızca cihaz şarjdayken çalışmasını sağlayan genel ayar.</li>
<li><b>Pil Ayarları</b>: Minimum pil seviyesi eşiğini ve pil koruma kurallarını yapılandırın.</li>
<li><b>Dil</b>: Uygulama arayüz dilini desteklenen 12 dil (Türkçe, English, Deutsch, Français, Español, Русский, العربية, 简体中文, 한국어, 日本語, Português, हिन्दी) arasında anında değiştirin.</li>
<li><b>Hakkında</b>: Yüklü uygulama <b>Sürüm</b> numarasını görün, <b>Uygulamayı Değerlendir</b> ile App Store'da puan verin veya <b>Destek İletişim</b> ile bize ulaşın.</li>
<li><b>Tüm Verileri Sıfırla</b>: Bu cihazdaki tüm görevleri, geçmişi ve kayıtlı parolaları siler. Sunucularınızdaki dosyalara hiçbir şekilde dokunulmaz.</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. Sorun giderme",
                """<dl>
<dt>Sunucuma bağlanamıyorum.</dt>
<dd><b>Sunucu Adresi</b>, <b>Port</b> (FTP: 21, SFTP: 22, WebDAV: 443/80), <b>Kullanıcı Adı</b> ve <b>Şifre</b> bilgilerini kontrol edin. Nextcloud/ownCloud WebDAV bağlantılarında yolun <code>/remote.php/dav/files/kullanici-adi/</code> şeklinde olduğundan emin olun. Ev ağındaki bir sunucuya bağlanıyorsanız iPhone'unuzun aynı Wi-Fi ağında olduğunu ve <b>iPhone Ayarlar › Gizlilik ve Güvenlik › Yerel Ağ › BackupFlow</b> izninin açık olduğunu doğrulayın.</dd>
<dt>Zamanlanmış yedekleme çalışmadı.</dt>
<dd>Görevin <b>Yedekleme davranışı</b> koşullarını (<b>Wi-Fi gerekli</b>, <b>Harici güç gerekli</b>, <b>İzinli saat aralığını kullan</b>) ve <b>Ayarlar › Pil Ayarları</b> ekranını kontrol edin. Ayrıca iOS Ayarlar'da BackupFlow için Bildirimler ve Arka Planda Uygulama Yenileme izinlerinin açık olduğundan emin olun.</dd>
<dt>Bazı fotoğraflar yedeklenmedi.</dt>
<dd>iOS Fotoğraflar izninin <b>Tam Erişim</b> olduğundan emin olun ve iCloud Fotoğrafları kullanıyorsanız <b>Gerekirse iCloud öğelerini indir</b> seçeneğini açın.</dd>
<dt>iPhone'dan sildiğim dosyalar sunucudan da silindi.</dt>
<dd>Görevinizin <b>Silme politikası</b> ayarı <b>Ayna</b> modundadır. Görevi düzenleyip <b>Sadece ekle</b> veya <b>Arşivli silme</b> olarak değiştirin.</dd>
<dt>SFTP güvenlik uyarısı alıyorum.</dt>
<dd>BackupFlow ilk bağlantıda SFTP sunucunuzun SSH parmak izini kaydeder ve değiştiğinde sizi uyarır. Sunucuyu yeniden kurduysanız veya değiştirdiyseniz bu durum normaldir; aksi halde devam etmeden önce sunucu yöneticinize danışın.</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. Gizlilik ve güvenlik",
                """<p>BackupFlow <b>yerel öncelikli gizlilik</b> mimarisiyle tasarlanmıştır: fotoğraf, video ve dosyalarınız doğrudan iPhone'unuzdan kendi sunucunuza aktarılır. BackupFlow'un hiçbir aracı sunucusu yoktur, dosyalarınızı asla görmez ve hiçbir analiz, takip veya reklam SDK'sı içermez.</p>
<p>Sunucu parolalarınız cihazınızdaki <b>iOS Keychain (Anahtarlık)</b> içinde şifreli olarak saklanır. Tüm detaylar için <a href="../../privacy-policy.html">Gizlilik Politikası</a> sayfamızı inceleyebilirsiniz.</p>""",
            ),
            (
                "help",
                "12. Yardım mı lazım?",
                """<p>Uygulama içinden <b>Ayarlar › Destek İletişim</b>'e dokunarak (veya <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a> adresine yazarak) bize e-posta gönderebilirsiniz. Uygulama sürümünüz ve cihaz modeliniz e-postaya otomatik olarak eklenir.</p>""",
            ),
        ],
    },

    "de": {
        "title": "BackupFlow Hilfe & Dokumentation",
        "description": "Vollständige Anleitung für BackupFlow auf iOS: Backup-Zentrale, FTP/SFTP/WebDAV-Einrichtung, Fotomediathek- und Dateien-Backup, Planung, Löschrichtlinien und Problemlösung.",
        "h1": "BackupFlow Hilfe",
        "lead": "BackupFlow sichert Fotos, Videos und Dateien von Ihrem iPhone per FTP, SFTP oder WebDAV direkt auf Ihrem eigenen Server – einem NAS, Heimserver oder Ihrer persönlichen Cloud. Ohne Abo und ohne Drittanbieter-Cloud.",
        "toc_title": "Auf dieser Seite",
        "sections": [
            (
                "what-you-need",
                "1. Was Sie brauchen",
                """<ul>
<li><b>Einen kompatiblen Server</b>: Ein NAS (Synology, QNAP, TrueNAS, Unraid), Heimserver oder eine persönliche Cloud (Nextcloud, ownCloud, WebDAV), die <b>FTP</b>, <b>SFTP (SSH)</b> oder <b>WebDAV (HTTP/HTTPS)</b> unterstützt.</li>
<li><b>Zugangsdaten</b>: Serveradresse (IP, Hostname oder WebDAV-URL), Port (Standard: FTP <b>21</b>, SFTP <b>22</b>, WebDAV <b>443</b>/<b>80</b>) sowie <b>Benutzername</b> und <b>Passwort</b> (oder <b>Anonyme Anmeldung</b> für FTP).</li>
<li><b>iOS-Berechtigungen</b>: Voller Zugriff auf Ihre <b>Fotos</b>, <b>Lokales Netzwerk</b> (für Server im Heimnetz) und <b>Mitteilungen</b> für Hintergrund-Backups.</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. Übersicht der Backup-Zentrale",
                """<p>Beim Öffnen von BackupFlow zeigt Ihnen die <b>Backup-Zentrale</b> alle wichtigen Statusinformationen auf einen Blick:</p>
<ul>
<li><b>Status-Banner</b>: Zeigt <b>Letzte Synchronisierung</b>, die <b>Nächste Aufgabe</b> mit Uhrzeit, den Status (<b>Sicher &amp; synchronisiert</b>), die Serveradresse und den grünen <b>Start-Button (▶)</b> zum sofortigen Starten eines Backups.</li>
<li><b>Backup-Zustand</b>: Zeigt Ihre <b>Erfolg</b>-Quote (Prozent und Läufe), aufeinanderfolgende <b>Fehler</b>, das letzte erfolgreiche Backup und die <b>Durchschnittliche Dauer</b>.</li>
<li><b>Gespeicherte Server</b>: Übersichtskarten für alle <b>FTP</b>-, <b>SFTP</b>- und <b>WebDAV</b>-Aufgaben mit Zielpfad sowie Schnellaktionen zum <b>Bearbeiten (✏️)</b> und <b>Löschen (🗑️)</b>. Tippen Sie auf eine Karte, um die <b>Aufgabendetails</b> zu öffnen.</li>
<li><b>Untere Leiste &amp; Einstellungen</b>: Über die drei Symbole unten starten Sie die <b>Synchronisierung (🔄)</b>, öffnen den <b>Backup-Verlauf (🕒)</b> oder erstellen über <b>+</b> ein <b>Neues Backup</b>. Das <b>Zahnrad-Symbol (⚙️)</b> oben rechts öffnet die <b>Einstellungen</b>.</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. Neues Backup erstellen",
                """<p>Tippen Sie in der <b>Backup-Zentrale</b> unten auf <b>+</b> oder neben <b>Gespeicherte Server</b> auf <b>Hinzufügen</b>, um <b>Neues Backup</b> zu öffnen:</p>
<ol>
<li><b>Quelle</b>: Wählen Sie <b>Fotomediathek</b> (<i>Nur Fotos</i>, <i>Nur Videos</i> oder <i>Fotos und Videos</i>) oder tippen Sie auf <b>Ordner auswählen</b>, um einen Ordner aus der iOS-App „Dateien“ zu sichern.</li>
<li><b>Zieltyp</b>: Wählen Sie <b>FTP</b>, <b>SFTP</b> oder <b>WebDAV</b>. Geben Sie <b>Serveradresse</b>, <b>Port</b>, <b>Benutzername</b> und <b>Passwort</b> (bzw. <b>Anonyme Anmeldung</b> bei FTP) sowie den Zielpfad (z. B. <code>/remote.php/dav/files/</code>) ein. Prüfen Sie die Eingaben mit <b>Verbindung testen</b> und wählen Sie den Zielordner optional über <b>Remote-Ordner durchsuchen</b> aus.</li>
<li><b>Planung</b>: Wählen Sie <b>Manuell</b>, <b>Tag</b>, <b>Woche</b>, <b>Monat</b> oder <b>Intervall</b> und legen Sie unter <b>Zeit auswählen</b> die Uhrzeit fest.</li>
<li><b>Backup-Verhalten</b>: Konfigurieren Sie <b>Löschrichtlinie</b>, <b>Prüfsumme</b> und Ausführungsbedingungen und speichern Sie die Aufgabe.</li>
</ol>
<p>Nach dem ersten vollständigen Backup überträgt BackupFlow nur noch <b>neue oder geänderte Dateien</b>, sodass Folge-Backups deutlich schneller abgeschlossen sind.</p>""",
            ),
            (
                "task-details",
                "4. Aufgabendetails & Verwaltung",
                """<p>Tippen Sie unter <b>Gespeicherte Server</b> auf eine Aufgabe, um die <b>Aufgabendetails</b> einzusehen:</p>
<ul>
<li><b>Allgemein</b>: Zeigt <b>Quelle</b>, <b>Status</b> (z. B. <b>Bereit</b>), <b>Zeitplan</b>, <b>Löschrichtlinie</b> und <b>Prüfsumme</b>.</li>
<li><b>Server</b>: Zeigt <b>Server</b>, <b>Port</b> und <b>Benutzer</b>.</li>
<li><b>Letzte Sicherungen</b>: Listet die letzten Durchläufe dieser Aufgabe samt Dateianzahl, Datenmenge und Dauer auf.</li>
<li>Über <b>Bearbeiten</b> oben links passen Sie die Aufgabe jederzeit an.</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. Planung & Bedingungen",
                """<p>Unter <b>Planung</b> wählen Sie das Ausführungsintervall: <b>Manuell</b>, <b>Tag</b>, <b>Woche</b>, <b>Monat</b> oder <b>Intervall</b> (mit Uhrzeit unter <b>Zeit auswählen</b>).</p>
<p>Unter <b>Backup-Verhalten</b> legen Sie fest, unter welchen Bedingungen automatische Backups starten dürfen:</p>
<ul>
<li><b>Wi-Fi erforderlich</b>: Verhindert die Nutzung mobiler Daten.</li>
<li><b>Externe Stromversorgung erforderlich</b>: Läuft nur, während das iPhone geladen wird.</li>
<li><b>Erlaubtes Zeitfenster verwenden</b>: Beschränkt automatische Backups auf bestimmte Uhrzeiten (z. B. nachts).</li>
<li><b>Minimaler Akkustand</b> (unter <b>Einstellungen › Akkueinstellungen</b>): Überspringt Backups bei niedrigem Akkustand.</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. Löschrichtlinie, Prüfsumme & iCloud",
                """<p>Unter <b>Backup-Verhalten</b> bestimmen Sie den Umgang mit gelöschten Dateien und die Dateiüberprüfung:</p>
<dl>
<dt>Löschrichtlinie › Nur hinzufügen</dt>
<dd>Auf dem Server wird niemals etwas gelöscht. <b>Empfohlen</b>, wenn Sie nach dem Backup Fotos auf dem iPhone löschen möchten, um Speicherplatz freizugeben.</dd>
<dt>Löschrichtlinie › Spiegeln</dt>
<dd>Der Zielordner bleibt ein exaktes Abbild der Quelle. Auf dem iPhone gelöschte Dateien werden beim nächsten Lauf auch auf dem Server entfernt.</dd>
<dt>Löschrichtlinie › Löschen archivieren</dt>
<dd>Entfernte Dateien werden nicht gelöscht, sondern auf dem Server in einen datierten Ordner <b>.backupflow_archive</b> verschoben.</dd>
<dt>Prüfsumme</dt>
<dd>Prüft nach dem Upload die Dateiintegrität auf dem Server (standardmäßig <b>Aus</b> für maximale Geschwindigkeit).</dd>
</dl>
<p class="note"><b>Tipp für iCloud-Fotos:</b> Aktivieren Sie <b>iCloud-Objekte bei Bedarf laden</b>, damit auch Fotos und Videos gesichert werden, deren Originale nur in iCloud gespeichert sind.</p>""",
            ),
            (
                "background",
                "7. Backups im Hintergrund",
                """<p>BackupFlow nutzt den iOS <b>BGTaskScheduler</b> für geplante Hintergrund-Backups. Da iOS den genauen Ausführungszeitpunkt anhand von Akkustand und Gerätenutzung steuert, kann ein geplantes Backup kurz nach der gewählten Uhrzeit starten oder eine Mitteilung senden.</p>
<p>Wird ein Backup durch iOS unterbrochen, setzt BackupFlow es beim nächsten Öffnen nahtlos fort und überspringt bereits übertragene Dateien. Halten Sie das iPhone beim ersten großen Backup im WLAN und am Ladegerät.</p>""",
            ),
            (
                "history",
                "8. Backup-Verlauf",
                """<p>Tippen Sie in der unteren Leiste der <b>Backup-Zentrale</b> auf das mittlere <b>Verlauf-Symbol (🕒)</b>, um den <b>Backup-Verlauf</b> zu öffnen:</p>
<ul>
<li><b>Übersichtskarten</b>: Zeigt die Anzahl für <b>Abgeschlossen</b>, <b>Fehlgeschlagen</b> sowie das gesamte <b>Übertragen</b>-Datenvolumen (GB/MB).</li>
<li><b>Verlaufsdetails</b>: Jeder Eintrag zeigt Aufgabenname, Zeitstempel, Status, <b>Dateien</b> (z. B. <code>1236/1236</code>), übertragene Größe und <b>Dauer</b>. Mit dem <b>Papierkorb-Symbol (🗑️)</b> oben rechts löschen Sie den Verlauf.</li>
</ul>""",
            ),
            (
                "settings",
                "9. Einstellungen",
                """<p>Über das <b>Zahnrad-Symbol (⚙️)</b> oben rechts in der <b>Backup-Zentrale</b> öffnen Sie die <b>Einstellungen</b>:</p>
<ul>
<li><b>Verlaufsaufbewahrung (Tage)</b>: Speicherdauer des Verlaufs (z. B. <b>30 Tage</b>).</li>
<li><b>Externe Stromversorgung erforderlich</b> &amp; <b>Akkueinstellungen</b>: Globale Strom- und Akkuschwellenwerte.</li>
<li><b>Sprache</b>: Wechseln Sie die App-Sprache direkt zwischen allen 12 unterstützten Sprachen.</li>
<li><b>Über</b>: Zeigt die <b>Version</b>, <b>App bewerten</b> und <b>Support kontaktieren</b>.</li>
<li><b>Alle Daten zurücksetzen</b>: Entfernt alle Aufgaben, Verläufe und gespeicherten Passwörter vom iPhone (Dateien auf Ihren Servern bleiben unberührt).</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. Problemlösung",
                """<dl>
<dt>Verbindung zum Server schlägt fehl.</dt>
<dd>Prüfen Sie Adresse, Port (FTP 21, SFTP 22, WebDAV 443/80), Benutzername und Passwort. Stellen Sie bei Heimservern sicher, dass das iPhone im selben WLAN ist und unter <b>iPhone-Einstellungen › Datenschutz &amp; Sicherheit › Lokales Netzwerk</b> der Zugriff für BackupFlow aktiviert ist.</dd>
<dt>Ein geplantes Backup wurde nicht ausgeführt.</dt>
<dd>Prüfen Sie die Bedingungen unter <b>Backup-Verhalten</b> (WLAN, Strom, Zeitfenster), die <b>Akkueinstellungen</b> sowie die Mitteilungsberechtigung.</dd>
<dt>Einige Fotos fehlen.</dt>
<dd>Aktivieren Sie den vollen Fotomediathek-Zugriff und schalten Sie <b>iCloud-Objekte bei Bedarf laden</b> ein.</dd>
<dt>Dateien wurden auf dem Server gelöscht.</dt>
<dd>Ändern Sie die <b>Löschrichtlinie</b> der Aufgabe von <b>Spiegeln</b> auf <b>Nur hinzufügen</b> oder <b>Löschen archivieren</b>.</dd>
<dt>SFTP-Sicherheitswarnung erscheint.</dt>
<dd>Der SSH-Fingerabdruck des Servers hat sich geändert. Das ist nach einer Neuinstallation normal; fragen Sie andernfalls Ihren Administrator.</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. Datenschutz & Sicherheit",
                """<p>Ihre Dateien werden direkt vom iPhone auf Ihren eigenen Server übertragen. BackupFlow betreibt keine eigenen Server, sieht Ihre Dateien nie und sammelt keinerlei Nutzungs- oder Analysedaten. Passwörter werden sicher im <b>iOS-Schlüsselbund (Keychain)</b> gespeichert. Weitere Details finden Sie in unserer <a href="../../privacy-policy.html">Datenschutzrichtlinie</a>.</p>""",
            ),
            (
                "help",
                "12. Brauchen Sie Hilfe?",
                """<p>Tippen Sie in der App auf <b>Einstellungen › Support kontaktieren</b> oder schreiben Sie an <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>. App-Version und Gerätemodell werden automatisch angehängt.</p>""",
            ),
        ],
    },

    "fr": {
        "title": "Aide et Documentation BackupFlow",
        "description": "Guide complet de BackupFlow pour iOS : Centre de sauvegarde, configuration FTP/SFTP/WebDAV, sauvegarde Photothèque et Fichiers, planification, politique de suppression et dépannage.",
        "h1": "Aide BackupFlow",
        "lead": "BackupFlow sauvegarde les photos, vidéos et fichiers de votre iPhone directement sur votre propre serveur — NAS, serveur domestique ou cloud personnel — via FTP, SFTP ou WebDAV. Sans abonnement ni cloud tiers.",
        "toc_title": "Sur cette page",
        "sections": [
            (
                "what-you-need",
                "1. Ce qu'il vous faut",
                """<ul>
<li><b>Un serveur compatible</b> : Tout NAS (Synology, QNAP, TrueNAS, Unraid), serveur domestique ou cloud personnel (Nextcloud, ownCloud, WebDAV) prenant en charge <b>FTP</b>, <b>SFTP (SSH)</b> ou <b>WebDAV (HTTP/HTTPS)</b>.</li>
<li><b>Vos identifiants</b> : Adresse du serveur, port (FTP <b>21</b>, SFTP <b>22</b>, WebDAV <b>443</b>/<b>80</b>), <b>Nom d'utilisateur</b> et <b>Mot de passe</b> (ou connexion anonyme pour FTP).</li>
<li><b>Autorisations iOS</b> : Accès complet à la <b>Photothèque</b>, accès au <b>Réseau local</b> (pour un serveur domestique) et <b>Notifications</b>.</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. Présentation du Centre de sauvegarde",
                """<p>À l'ouverture de l'application, le <b>Centre de sauvegarde</b> affiche l'état complet de vos sauvegardes en temps réel :</p>
<ul>
<li><b>Carte d'état</b> : Indique la dernière synchronisation, l'heure de la prochaine tâche, l'état global, l'adresse du serveur et le bouton vert <b>Lecture (▶)</b> pour lancer une sauvegarde immédiatement.</li>
<li><b>Santé des sauvegardes</b> : Affiche le taux de réussite, le nombre d'échecs consécutifs, la dernière sauvegarde réussie et la durée moyenne.</li>
<li><b>Serveurs enregistrés</b> : Liste vos tâches <b>FTP</b>, <b>SFTP</b> et <b>WebDAV</b> avec des boutons rapides pour <b>Modifier (✏️)</b> ou <b>Supprimer (🗑️)</b>. Touchez une carte pour ouvrir les <b>Détails de la tâche</b>.</li>
<li><b>Barre inférieure et Paramètres</b> : Utilisez les trois boutons en bas de l'écran pour <b>Synchroniser (🔄)</b>, ouvrir l'<b>Historique (🕒)</b> ou créer une <b>Nouvelle sauvegarde (+)</b>. L'icône <b>engrenage (⚙️)</b> en haut à droite ouvre les <b>Paramètres</b>.</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. Créer une nouvelle sauvegarde",
                """<p>Touchez le bouton <b>+</b> en bas du <b>Centre de sauvegarde</b> (ou <b>Ajouter</b> à côté de <b>Serveurs enregistrés</b>) pour ouvrir <b>Nouvelle sauvegarde</b> :</p>
<ol>
<li><b>Source</b> : Choisissez la <b>Photothèque</b> (photos, vidéos ou les deux) ou touchez <b>Sélectionner un dossier</b> pour choisir un dossier dans l'app <b>Fichiers</b> d'iOS.</li>
<li><b>Type de cible</b> : Sélectionnez <b>FTP</b>, <b>SFTP</b> ou <b>WebDAV</b>. Saisissez l'adresse du serveur, le port, le <b>Nom d'utilisateur</b>, le <b>Mot de passe</b> et le chemin distant (ex. <code>/remote.php/dav/files/</code>). Touchez <b>Tester la connexion</b> puis <b>Parcourir le dossier distant</b> pour choisir le dossier cible.</li>
<li><b>Planification</b> : Choisissez <b>Manuel</b>, <b>Jour</b>, <b>Semaine</b>, <b>Mois</b> ou <b>Intervalle</b>, et réglez l'heure sous <b>Sélectionner l'heure</b>.</li>
<li><b>Comportement de sauvegarde</b> : Configurez la <b>Politique de suppression</b>, la <b>Somme de contrôle</b> et les conditions d'exécution, puis enregistrez la tâche.</li>
</ol>
<p>Après la première sauvegarde complète, seuls les fichiers nouveaux ou modifiés sont transférés, ce qui rend les sauvegardes suivantes beaucoup plus rapides.</p>""",
            ),
            (
                "task-details",
                "4. Détails et gestion des tâches",
                """<p>Touchez une tâche sous <b>Serveurs enregistrés</b> pour afficher les <b>Détails de la tâche</b> :</p>
<ul>
<li><b>Général</b> : Consultez la source, l'état actuel, la planification, la <b>Politique de suppression</b> et l'option <b>Somme de contrôle</b>.</li>
<li><b>Serveur</b> : Vérifiez l'adresse du serveur, le port et l'utilisateur.</li>
<li><b>Sauvegardes récentes</b> : Consultez les dernières exécutions de cette tâche (date, statut, nombre de fichiers, taille et durée).</li>
<li>Touchez <b>Modifier</b> en haut à gauche pour ajuster les réglages de la tâche.</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. Planification et conditions",
                """<p>Dans <b>Planification</b>, choisissez la fréquence : <b>Manuel</b>, <b>Jour</b>, <b>Semaine</b>, <b>Mois</b> ou <b>Intervalle</b>, avec l'heure souhaitée sous <b>Sélectionner l'heure</b>.</p>
<p>Sous <b>Comportement de sauvegarde</b>, définissez les conditions requises :</p>
<ul>
<li><b>Wi-Fi requis</b> : N'utilise jamais les données mobiles.</li>
<li><b>Alimentation externe requise</b> : S'exécute uniquement lorsque l'iPhone est en charge.</li>
<li><b>Utiliser la plage horaire autorisée</b> : Limite les sauvegardes automatiques à une tranche horaire (par exemple la nuit).</li>
<li><b>Niveau minimum de batterie</b> (dans <b>Paramètres › Paramètres de batterie</b>) : Suspend la sauvegarde si la batterie est trop faible.</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. Politique de suppression, Somme de contrôle et iCloud",
                """<p>Sous <b>Comportement de sauvegarde</b>, choisissez comment gérer les fichiers supprimés et la vérification d'intégrité :</p>
<dl>
<dt>Politique de suppression › Ajout uniquement</dt>
<dd>Rien n'est jamais supprimé du serveur. <b>Recommandé</b> si vous souhaitez libérer de l'espace sur l'iPhone après la sauvegarde tout en conservant vos photos sur le serveur.</dd>
<dt>Politique de suppression › Miroir</dt>
<dd>Le dossier distant reste une copie exacte de la source. Les fichiers supprimés sur l'iPhone sont également supprimés du serveur.</dd>
<dt>Politique de suppression › Suppression archivée</dt>
<dd>Les fichiers retirés sur l'iPhone sont déplacés vers un dossier daté <b>.backupflow_archive</b> sur le serveur.</dd>
<dt>Somme de contrôle</dt>
<dd>Vérifie l'intégrité de chaque fichier après l'envoi (réglé sur <b>Désactivé</b> par défaut pour une vitesse maximale).</dd>
</dl>
<p class="note"><b>Astuce Photos iCloud :</b> Activez <b>Télécharger les éléments iCloud si nécessaire</b> pour sauvegarder également les originaux stockés uniquement sur iCloud.</p>""",
            ),
            (
                "background",
                "7. Sauvegarde en arrière-plan",
                """<p>BackupFlow utilise <b>BGTaskScheduler</b> d'iOS pour exécuter les sauvegardes planifiées. Comme iOS gère le moment exact d'exécution en fonction de la batterie et de l'utilisation de l'appareil, la tâche peut démarrer légèrement après l'heure choisie ou envoyer une notification.</p>
<p>Si iOS interrompt un transfert, ouvrez simplement BackupFlow : la sauvegarde reprend automatiquement en ignorant les fichiers déjà envoyés. Pour une première sauvegarde volumineuse, gardez l'iPhone connecté au Wi-Fi et au chargeur.</p>""",
            ),
            (
                "history",
                "8. Historique des sauvegardes",
                """<p>Touchez le bouton central <b>Historique (🕒)</b> en bas du <b>Centre de sauvegarde</b> :</p>
<ul>
<li><b>Cartes récapitulatives</b> : Affichez le total des sauvegardes réussies, échouées et le volume total transféré (Go/Mo).</li>
<li><b>Journaux détaillés</b> : Chaque entrée indique le nom de la tâche, la date, le nombre de fichiers envoyés, la taille transférée et la durée. L'icône <b>corbeille (🗑️)</b> en haut à droite permet d'effacer l'historique.</li>
</ul>""",
            ),
            (
                "settings",
                "9. Paramètres de l'application",
                """<p>Touchez l'icône <b>engrenage (⚙️)</b> en haut à droite du <b>Centre de sauvegarde</b> pour ouvrir les <b>Paramètres</b> :</p>
<ul>
<li><b>Rétention de l'historique (jours)</b> : Durée de conservation de l'historique (ex. <b>30 jours</b>).</li>
<li><b>Alimentation externe requise</b> et <b>Paramètres de batterie</b> : Règles globales d'alimentation et de batterie.</li>
<li><b>Langue</b> : Changez la langue de l'application à tout moment parmi les 12 langues prises en charge.</li>
<li><b>À propos</b> : Consultez la <b>Version</b>, touchez <b>Évaluer l'application</b> ou <b>Contacter le support</b>.</li>
<li><b>Réinitialiser toutes les données</b> : Supprime toutes les tâches, l'historique et les mots de passe enregistrés sur cet iPhone sans toucher aux fichiers présents sur vos serveurs.</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. Dépannage",
                """<dl>
<dt>Impossible de me connecter au serveur.</dt>
<dd>Vérifiez l'adresse, le port (FTP 21, SFTP 22, WebDAV 443/80), le nom d'utilisateur et le mot de passe. Sur un réseau domestique, vérifiez que l'iPhone est sur le même Wi-Fi et que l'accès est autorisé dans <b>Réglages de l'iPhone › Confidentialité et sécurité › Réseau local › BackupFlow</b>.</dd>
<dt>Une sauvegarde planifiée ne s'est pas lancée.</dt>
<dd>Vérifiez les conditions sous <b>Comportement de sauvegarde</b> (Wi-Fi, alimentation, plage horaire, batterie) ainsi que les notifications.</dd>
<dt>Certaines photos manquent.</dt>
<dd>Autorisez l'accès complet aux Photos et activez <b>Télécharger les éléments iCloud si nécessaire</b>.</dd>
<dt>Des fichiers ont disparu de mon serveur.</dt>
<dd>Votre tâche utilise la politique <b>Miroir</b>. Passez-la sur <b>Ajout uniquement</b> ou <b>Suppression archivée</b>.</dd>
<dt>Avertissement de sécurité SFTP.</dt>
<dd>L'empreinte SSH du serveur a changé. C'est normal après une réinstallation du serveur ; sinon, vérifiez auprès de votre administrateur.</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. Confidentialité et sécurité",
                """<p>Vos fichiers sont transférés directement de votre iPhone vers votre propre serveur. BackupFlow ne possède aucun serveur intermédiaire, ne voit jamais vos fichiers et ne collecte aucune donnée personnelle ou analytique. Vos mots de passe sont chiffrés dans le <b>Trousseau iOS (Keychain)</b>. Consultez notre <a href="../../privacy-policy.html">Politique de confidentialité</a> complète.</p>""",
            ),
            (
                "help",
                "12. Besoin d'aide ?",
                """<p>Ouvrez <b>Paramètres › Contacter le support</b> dans l'application (ou écrivez à <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>). La version de l'application et le modèle de votre iPhone sont ajoutés automatiquement.</p>""",
            ),
        ],
    },

    "es": {
        "title": "Ayuda y Documentación de BackupFlow",
        "description": "Guía completa de BackupFlow para iOS: Centro de copias, configuración FTP/SFTP/WebDAV, copia de Biblioteca de fotos y Archivos, programación, políticas de eliminación y solución de problemas.",
        "h1": "Ayuda de BackupFlow",
        "lead": "BackupFlow copia las fotos, vídeos y archivos de tu iPhone directamente en tu propio servidor — un NAS, servidor doméstico o nube personal — mediante FTP, SFTP o WebDAV. Sin suscripciones ni nubes de terceros.",
        "toc_title": "En esta página",
        "sections": [
            (
                "what-you-need",
                "1. Qué necesitas",
                """<ul>
<li><b>Un servidor compatible</b>: Cualquier NAS (Synology, QNAP, TrueNAS, Unraid), servidor doméstico o nube personal (Nextcloud, ownCloud, WebDAV) compatible con <b>FTP</b>, <b>SFTP (SSH)</b> o <b>WebDAV (HTTP/HTTPS)</b>.</li>
<li><b>Datos de acceso</b>: Dirección del servidor, puerto (FTP <b>21</b>, SFTP <b>22</b>, WebDAV <b>443</b>/<b>80</b>), <b>Nombre de usuario</b> y <b>Contraseña</b> (o inicio anónimo para FTP).</li>
<li><b>Permisos de iOS</b>: Acceso completo a <b>Fotos</b>, acceso a <b>Red local</b> (si el servidor está en tu red doméstica) y <b>Notificaciones</b>.</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. Vista general del Centro de copias",
                """<p>Al abrir BackupFlow, el <b>Centro de copias</b> muestra en tiempo real el estado de tus copias de seguridad:</p>
<ul>
<li><b>Tarjeta de estado</b>: Muestra la última sincronización, la hora de la próxima tarea, el estado de protección, la dirección del servidor y el botón verde <b>Reproducir (▶)</b> para iniciar una copia al instante.</li>
<li><b>Salud de las copias</b>: Muestra el porcentaje de éxito, los fallos consecutivos, la fecha de la última copia exitosa y la duración media.</li>
<li><b>Servidores guardados</b>: Tarjetas para tus tareas <b>FTP</b>, <b>SFTP</b> y <b>WebDAV</b> con botones rápidos para <b>Editar (✏️)</b> o <b>Eliminar (🗑️)</b>. Toca cualquier tarjeta para abrir los <b>Detalles de la tarea</b>.</li>
<li><b>Barra inferior y Ajustes</b>: Usa los tres botones inferiores para <b>Sincronizar (🔄)</b>, abrir el <b>Historial de copias (🕒)</b> o crear una <b>Nueva copia de seguridad (+)</b>. El icono de <b>engranaje (⚙️)</b> arriba a la derecha abre <b>Ajustes</b>.</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. Crear una nueva copia de seguridad",
                """<p>Toca el botón <b>+</b> en la parte inferior del <b>Centro de copias</b> (o <b>Añadir</b> junto a <b>Servidores guardados</b>) para abrir <b>Nueva copia de seguridad</b>:</p>
<ol>
<li><b>Origen</b>: Elige <b>Biblioteca de fotos</b> (solo fotos, solo vídeos o ambos) o toca <b>Seleccionar carpeta</b> para elegir cualquier carpeta de la app <b>Archivos</b> de iOS.</li>
<li><b>Tipo de destino</b>: Selecciona <b>FTP</b>, <b>SFTP</b> o <b>WebDAV</b>. Introduce la dirección del servidor, el puerto, el <b>Nombre de usuario</b>, la <b>Contraseña</b> y la ruta remota (ej. <code>/remote.php/dav/files/</code>). Toca <b>Probar conexión</b> y opcionalmente <b>Explorar carpeta remota</b> para elegir la carpeta en tu servidor.</li>
<li><b>Programación</b>: Elige <b>Manual</b>, <b>Diario</b>, <b>Semanal</b>, <b>Mensual</b> o <b>Intervalo</b>, y define la hora en <b>Seleccionar hora</b>.</li>
<li><b>Comportamiento de la copia</b>: Configura la <b>Política de eliminación</b>, la <b>Suma de verificación</b> y las condiciones de red/energía, y guarda la tarea.</li>
</ol>
<p>Tras la primera copia completa, solo se envían los archivos nuevos o modificados, haciendo que las siguientes copias sean mucho más rápidas.</p>""",
            ),
            (
                "task-details",
                "4. Detalles y gestión de tareas",
                """<p>Toca cualquier tarea en <b>Servidores guardados</b> para ver los <b>Detalles de la tarea</b>:</p>
<ul>
<li><b>General</b>: Revisa el origen, el estado actual, la programación, la <b>Política de eliminación</b> y la <b>Suma de verificación</b>.</li>
<li><b>Servidor</b>: Consulta la dirección del servidor, el puerto y el usuario.</li>
<li><b>Copias recientes</b>: Revisa las últimas ejecuciones de esa tarea con fecha, estado, archivos transferidos, tamaño y duración.</li>
<li>Toca <b>Editar</b> arriba a la izquierda para modificar cualquier ajuste de la tarea.</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. Programación y condiciones",
                """<p>En <b>Programación</b> puedes elegir: <b>Manual</b>, <b>Diario</b>, <b>Semanal</b>, <b>Mensual</b> o <b>Intervalo</b>, ajustando la hora en <b>Seleccionar hora</b>.</p>
<p>En <b>Comportamiento de la copia</b> puedes definir cuándo se permite ejecutar la copia automática:</p>
<ul>
<li><b>Requiere Wi-Fi</b>: Evita el uso de datos móviles.</li>
<li><b>Requiere alimentación externa</b>: Solo se ejecuta mientras el iPhone se está cargando.</li>
<li><b>Usar intervalo horario permitido</b>: Limita las copias automáticas a una franja horaria (por ejemplo, de noche).</li>
<li><b>Nivel mínimo de batería</b> (en <b>Ajustes › Ajustes de batería</b>): Omite la copia si la batería está baja.</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. Política de eliminación, Suma de verificación e iCloud",
                """<p>En <b>Comportamiento de la copia</b> controlas qué ocurre en el servidor cuando borras archivos en el iPhone y cómo se verifican las subidas:</p>
<dl>
<dt>Política de eliminación › Solo añadir</dt>
<dd>Nunca se borra nada del servidor. <b>Recomendado</b> si planeas borrar fotos o vídeos del iPhone para liberar espacio después de hacer la copia.</dd>
<dt>Política de eliminación › Espejo</dt>
<dd>Mantiene la carpeta del servidor como una copia exacta del origen. Los archivos borrados en el iPhone también se eliminan del servidor.</dd>
<dt>Política de eliminación › Archivado al borrar</dt>
<dd>Los archivos eliminados en el iPhone se mueven a una carpeta con fecha <b>.backupflow_archive</b> en el servidor.</dd>
<dt>Suma de verificación</dt>
<dd>Comprueba que cada archivo llegue intacto al servidor tras la subida (por defecto <b>Desactivado</b> para máxima velocidad).</dd>
</dl>
<p class="note"><b>Consejo para Fotos en iCloud:</b> Activa <b>Descargar elementos de iCloud si es necesario</b> para copiar también los originales que solo están almacenados en iCloud.</p>""",
            ),
            (
                "background",
                "7. Copias en segundo plano",
                """<p>BackupFlow utiliza <b>BGTaskScheduler</b> de iOS para ejecutar copias programadas en segundo plano. Dado que iOS decide el momento exacto según el uso y la batería, una tarea programada puede comenzar unos minutos después de la hora elegida o enviarte una notificación.</p>
<p>Si iOS detiene una copia antes de terminar, abre BackupFlow y continuará automáticamente omitiendo los archivos ya enviados. Para una primera copia grande, mantén el iPhone conectado al Wi-Fi y a la corriente.</p>""",
            ),
            (
                "history",
                "8. Historial de copias",
                """<p>Toca el botón central <b>Historial (🕒)</b> en la barra inferior del <b>Centro de copias</b>:</p>
<ul>
<li><b>Tarjetas de resumen</b>: Consulta el total de copias completadas, fallidas y el total de datos transferidos (GB/MB).</li>
<li><b>Registros detallados</b>: Cada entrada muestra el nombre de la tarea, la fecha, los archivos transferidos, el tamaño y la duración. Usa el icono de <b>papelera (🗑️)</b> arriba a la derecha para borrar el historial.</li>
</ul>""",
            ),
            (
                "settings",
                "9. Ajustes de la aplicación",
                """<p>Toca el icono de <b>engranaje (⚙️)</b> arriba a la derecha en el <b>Centro de copias</b> para abrir <b>Ajustes</b>:</p>
<ul>
<li><b>Retención de historial (días)</b>: Elige cuántos días se guarda el historial (ej. <b>30 días</b>).</li>
<li><b>Requiere alimentación externa</b> y <b>Ajustes de batería</b>: Reglas globales de energía y nivel mínimo de batería.</li>
<li><b>Idioma</b>: Cambia el idioma de la aplicación al instante entre los 12 idiomas disponibles.</li>
<li><b>Acerca de</b>: Consulta la <b>Versión</b>, toca <b>Valorar aplicación</b> o <b>Contactar soporte</b>.</li>
<li><b>Restablecer todos los datos</b>: Elimina todas las tareas, el historial y las contraseñas guardadas de este iPhone sin tocar los archivos de tus servidores.</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. Solución de problemas",
                """<dl>
<dt>No puedo conectar con mi servidor.</dt>
<dd>Revisa la dirección, el puerto (FTP 21, SFTP 22, WebDAV 443/80), el usuario y la contraseña. Si el servidor está en casa, asegúrate de que el iPhone está en el mismo Wi-Fi y de que el permiso está activo en <b>Ajustes del iPhone › Privacidad y seguridad › Red local › BackupFlow</b>.</dd>
<dt>Una copia programada no se ejecutó.</dt>
<dd>Revisa las condiciones en <b>Comportamiento de la copia</b> (Wi-Fi, alimentación, intervalo horario, batería) y los permisos de notificaciones.</dd>
<dt>Faltan algunas fotos.</dt>
<dd>Concede acceso completo a Fotos y activa <b>Descargar elementos de iCloud si es necesario</b>.</dd>
<dt>Han desaparecido archivos de mi servidor.</dt>
<dd>Cambia la <b>Política de eliminación</b> de la tarea de <b>Espejo</b> a <b>Solo añadir</b> o <b>Archivado al borrar</b>.</dd>
<dt>Aviso de seguridad SFTP.</dt>
<dd>La huella SSH del servidor ha cambiado. Es normal si reinstalaste o cambiaste el servidor; de lo contrario, consulta con el administrador.</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. Privacidad y seguridad",
                """<p>Tus archivos van directamente desde tu iPhone a tu propio servidor. BackupFlow no tiene servidores propios, nunca ve tus archivos y no recopila datos ni estadísticas. Las contraseñas se guardan cifradas en el <b>Llavero de iOS (Keychain)</b>. Consulta nuestra <a href="../../privacy-policy.html">Política de privacidad</a> completa.</p>""",
            ),
            (
                "help",
                "12. ¿Necesitas ayuda?",
                """<p>Ve a <b>Ajustes › Contactar soporte</b> dentro de la app (o escribe a <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>). La versión de la app y el modelo del dispositivo se adjuntan automáticamente.</p>""",
            ),
        ],
    },

    "ru": {
        "title": "Справка и документация BackupFlow",
        "description": "Полное руководство по BackupFlow для iOS: Центр копий, настройка FTP/SFTP/WebDAV, резервное копирование Фото и Файлов, расписание, политика удаления и решение проблем.",
        "h1": "Справка BackupFlow",
        "lead": "BackupFlow сохраняет фото, видео и файлы с вашего iPhone напрямую на ваш собственный сервер — NAS, домашний сервер или личное облако — по протоколам FTP, SFTP или WebDAV. Без подписок и сторонних облаков.",
        "toc_title": "На этой странице",
        "sections": [
            (
                "what-you-need",
                "1. Что понадобится",
                """<ul>
<li><b>Совместимый сервер</b>: Любой NAS (Synology, QNAP, TrueNAS, Unraid), домашний сервер или личное облако (Nextcloud, ownCloud, WebDAV) с поддержкой <b>FTP</b>, <b>SFTP (SSH)</b> или <b>WebDAV (HTTP/HTTPS)</b>.</li>
<li><b>Данные для входа</b>: Адрес сервера, порт (FTP <b>21</b>, SFTP <b>22</b>, WebDAV <b>443</b>/<b>80</b>), <b>Имя пользователя</b> и <b>Пароль</b> (или анонимный вход для FTP).</li>
<li><b>Разрешения iOS</b>: Полный доступ к <b>Фото</b>, доступ к <b>Локальной сети</b> (для домашнего сервера) и <b>Уведомления</b>.</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. Обзор Центра копий",
                """<p>Главный экран <b>Центр копий</b> показывает состояние ваших резервных копий в реальном времени:</p>
<ul>
<li><b>Карточка статуса</b>: Показывает время последней синхронизации, следующую задачу, статус защиты, адрес сервера и зелёную кнопку <b>Запуск (▶)</b> для немедленного старта копирования.</li>
<li><b>Здоровье копий</b>: Отображает процент успешных запусков, количество ошибок подряд, дату последней успешной копии и среднюю длительность.</li>
<li><b>Сохраненные серверы</b>: Карточки ваших задач <b>FTP</b>, <b>SFTP</b> и <b>WebDAV</b> с быстрыми кнопками <b>Изменить (✏️)</b> и <b>Удалить (🗑️)</b>. Нажмите на карточку, чтобы открыть <b>Детали задачи</b>.</li>
<li><b>Нижняя панель и Настройки</b>: Три кнопки внизу позволяют <b>Синхронизировать (🔄)</b>, открыть <b>Историю копий (🕒)</b> или создать <b>Новую копию (+)</b>. Значок <b>шестерёнки (⚙️)</b> в правом верхнем углу открывает <b>Настройки</b>.</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. Создание новой резервной копии",
                """<p>Нажмите кнопку <b>+</b> внизу <b>Центра копий</b> (или <b>Добавить</b> рядом с <b>Сохраненные серверы</b>), чтобы открыть экран <b>Новая копия</b>:</p>
<ol>
<li><b>Источник</b>: Выберите <b>Фото медиатека</b> (только фото, только видео или всё вместе) или нажмите <b>Выбрать папку</b>, чтобы указать любую папку из приложения «Файлы».</li>
<li><b>Тип цели</b>: Выберите <b>FTP</b>, <b>SFTP</b> или <b>WebDAV</b>. Введите адрес сервера, порт, <b>Имя пользователя</b>, <b>Пароль</b> и удалённый путь (например, <code>/remote.php/dav/files/</code>). Нажмите <b>Проверить соединение</b>, а затем при необходимости <b>Выбрать удаленную папку</b>.</li>
<li><b>Расписание</b>: Выберите <b>Вручную</b>, <b>День</b>, <b>Неделя</b>, <b>Месяц</b> или <b>Интервал</b> и укажите время в поле <b>Выбрать время</b>.</li>
<li><b>Поведение резервного копирования</b>: Настройте <b>Политику удаления</b>, <b>Контрольную сумму</b> и условия запуска, затем сохраните задачу.</li>
</ol>
<p>После первой полной копии передаются только новые или изменённые файлы, поэтому последующие копии выполняются намного быстрее.</p>""",
            ),
            (
                "task-details",
                "4. Детали задачи и управление",
                """<p>Нажмите на любую задачу в разделе <b>Сохраненные серверы</b>, чтобы открыть <b>Детали задачи</b>:</p>
<ul>
<li><b>Общие</b>: Просмотр источника, текущего статуса, расписания, <b>Политики удаления</b> и параметра <b>Контрольная сумма</b>.</li>
<li><b>Сервер</b>: Просмотр адреса сервера, порта и имени пользователя.</li>
<li><b>Последние копии</b>: Список последних запусков этой задачи с датой, статусом, числом файлов, объёмом и длительностью.</li>
<li>Нажмите <b>Изменить</b> в левом верхнем углу для редактирования задачи.</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. Расписание и условия запуска",
                """<p>В разделе <b>Расписание</b> доступны режимы: <b>Вручную</b>, <b>День</b>, <b>Неделя</b>, <b>Месяц</b> и <b>Интервал</b> с выбором точного времени (<b>Выбрать время</b>).</p>
<p>В разделе <b>Поведение резервного копирования</b> можно задать условия для автоматического запуска:</p>
<ul>
<li><b>Требуется Wi-Fi</b>: Исключает использование мобильного интернета.</li>
<li><b>Требуется внешнее питание</b>: Копирование выполняется только во время зарядки iPhone.</li>
<li><b>Использовать разрешенное время</b>: Ограничивает работу выбранным временным окном (например, только ночью).</li>
<li><b>Минимальный уровень батареи</b> (в <b>Настройки › Настройки батареи</b>): Откладывает копирование при низком заряде.</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. Политика удаления, Контрольная сумма и iCloud",
                """<p>В разделе <b>Поведение резервного копирования</b> настраивается обработка удалённых файлов и проверка целостности:</p>
<dl>
<dt>Политика удаления › Только добавлять</dt>
<dd>С сервера никогда ничего не удаляется. <b>Рекомендуется</b>, если после резервного копирования вы планируете удалять фото с iPhone для освобождения памяти.</dd>
<dt>Политика удаления › Зеркало</dt>
<dd>Папка на сервере остаётся точной копией источника. Файлы, удалённые на iPhone, удаляются и с сервера.</dd>
<dt>Политика удаления › Архивное удаление</dt>
<dd>Удалённые на iPhone файлы не стираются, а перемещаются в папку <b>.backupflow_archive</b> с датой на сервере.</dd>
<dt>Контрольная сумма</dt>
<dd>Проверяет целостность каждого загруженного файла на сервере (по умолчанию <b>Выкл.</b> для максимальной скорости).</dd>
</dl>
<p class="note"><b>Совет для Фото iCloud:</b> Включите <b>Загружать элементы iCloud при необходимости</b>, чтобы копировать оригиналы фото и видео, которые хранятся только в iCloud.</p>""",
            ),
            (
                "background",
                "7. Копирование в фоновом режиме",
                """<p>BackupFlow использует системный планировщик iOS <b>BGTaskScheduler</b>. Поскольку iOS сама выбирает точное время фонового запуска в зависимости от заряда и использования устройства, задача может запуститься чуть позже выбранной минуты или прислать уведомление.</p>
<p>Если iOS приостановит передачу, просто откройте BackupFlow — копирование продолжится с того же места, а уже загруженные файлы будут пропущены. Для первой большой копии держите iPhone на Wi-Fi и зарядке.</p>""",
            ),
            (
                "history",
                "8. История копий",
                """<p>Нажмите среднюю кнопку <b>История (🕒)</b> на нижней панели <b>Центра копий</b>:</p>
<ul>
<li><b>Сводные карточки</b>: Показывают общее количество успешных и неудачных запусков, а также общий объём переданных данных (ГБ/МБ).</li>
<li><b>Подробный журнал</b>: В каждой записи указаны название задачи, дата, статус, количество файлов, размер и длительность. Значок <b>корзины (🗑️)</b> в правом верхнем углу очищает историю.</li>
</ul>""",
            ),
            (
                "settings",
                "9. Настройки приложения",
                """<p>Нажмите на значок <b>шестерёнки (⚙️)</b> в правом верхнем углу <b>Центра копий</b>, чтобы открыть <b>Настройки</b>:</p>
<ul>
<li><b>Хранение истории (дни)</b>: Срок хранения записей журнала (например, <b>30 дней</b>).</li>
<li><b>Требуется внешнее питание</b> и <b>Настройки батареи</b>: Глобальные правила питания и минимального заряда.</li>
<li><b>Язык</b>: Мгновенное переключение языка интерфейса среди 12 поддерживаемых языков.</li>
<li><b>О приложении</b>: Номер <b>Версии</b>, кнопки <b>Оценить приложение</b> и <b>Связаться с поддержкой</b>.</li>
<li><b>Сбросить все данные</b>: Удаляет все задачи, историю и сохранённые пароли с этого iPhone. Файлы на ваших серверах остаются нетронутыми.</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. Решение проблем",
                """<dl>
<dt>Не удаётся подключиться к серверу.</dt>
<dd>Проверьте адрес, порт (FTP 21, SFTP 22, WebDAV 443/80), логин и пароль. Для домашнего сервера убедитесь, что iPhone подключён к той же сети Wi-Fi и доступ разрешён в <b>Настройки iPhone › Конфиденциальность и безопасность › Локальная сеть › BackupFlow</b>.</dd>
<dt>Запланированная копия не запустилась.</dt>
<dd>Проверьте условия в разделе <b>Поведение резервного копирования</b> (Wi-Fi, питание, временное окно, батарея) и разрешения на уведомления.</dd>
<dt>Не хватает некоторых фотографий.</dt>
<dd>Разрешите полный доступ к Фото и включите <b>Загружать элементы iCloud при необходимости</b>.</dd>
<dt>Файлы пропали с сервера.</dt>
<dd>Измените <b>Политику удаления</b> задачи с <b>Зеркало</b> на <b>Только добавлять</b> или <b>Архивное удаление</b>.</dd>
<dt>Предупреждение безопасности SFTP.</dt>
<dd>Изменился SSH-отпечаток сервера. Это нормально после переустановки сервера; иначе обратитесь к администратору сервера.</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. Конфиденциальность и безопасность",
                """<p>Ваши файлы передаются напрямую с iPhone на ваш собственный сервер. У BackupFlow нет собственных серверов, приложение никогда не видит ваши файлы и не собирает никаких данных. Пароли надёжно зашифрованы в <b>Связке ключей iOS (Keychain)</b>. Подробности читайте в нашей <a href="../../privacy-policy.html">Политике конфиденциальности</a>.</p>""",
            ),
            (
                "help",
                "12. Нужна помощь?",
                """<p>Откройте <b>Настройки › Связаться с поддержкой</b> в приложении (или напишите на <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>). Версия приложения и модель устройства добавляются в письмо автоматически.</p>""",
            ),
        ],
    },
}
