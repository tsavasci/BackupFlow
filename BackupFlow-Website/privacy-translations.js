/* Localized Privacy Policy content for all 12 supported languages. */
window.BF_PRIVACY = {
  "en": {
    "title": "Privacy Policy - BackupFlow",
    "description": "BackupFlow Privacy Policy — Learn how BackupFlow protects your photos, videos, files, and server credentials with strict local-first privacy on iOS.",
    "h1": "Privacy Policy",
    "updated": "Last updated: October 2026",
    "lead": "BackupFlow is built from the ground up with local-first privacy. Your photos, videos, files, and server credentials never touch our servers or any third-party cloud.",
    "toc_title": "On this page",
    "summary_title": "Privacy Summary",
    "summary_text": "BackupFlow is designed with your privacy as the top priority. We do not collect, store, or have access to your personal data, photos, videos, files, or server credentials. Every backup goes directly from your iPhone to your own server, giving you 100% ownership and control.",
    "sections": [
      [
        "introduction",
        "1. Introduction",
        "<p>Welcome to BackupFlow. We are committed to protecting your privacy and ensuring the security of your data. This Privacy Policy explains how BackupFlow handles information when you use our iOS application and website.</p>\n<p><b>Core Principle:</b> BackupFlow operates on a strict <b>local-first, zero-knowledge architecture</b>. Your photos, videos, documents, and server credentials are never uploaded to our servers or any third-party cloud service. All transfers occur directly between your iPhone and the server you configure (NAS, home server, or personal cloud).</p>"
      ],
      [
        "not-collected",
        "2. Information We Do NOT Collect",
        "<p>BackupFlow does <b>not</b> collect, transmit, store, or sell any of the following:</p>\n<ul>\n<li>Your photos, videos, or media metadata</li>\n<li>Files or folders selected from the iOS Files app</li>\n<li>Your server addresses, hostnames, ports, usernames, or passwords</li>\n<li>Your backup tasks, schedules, or backup history logs</li>\n<li>Device identifiers, advertising IDs (IDFA), or usage analytics</li>\n<li>Your IP address, precise location, or contacts</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. How Your Data Stays Private",
        "<h3>3.1 Local Device Storage &amp; iOS Keychain</h3>\n<p>All backup task configurations, schedules, history logs, and app preferences are stored locally on your iPhone. Sensitive credentials (such as FTP, SFTP, and WebDAV passwords) are encrypted inside the <b>iOS Keychain</b> and never leave your device except when authenticating directly with your own server.</p>\n<h3>3.2 Direct Device-to-Server Transfer</h3>\n<p>When a backup runs, your files are transferred directly from your iPhone to your designated server using standard protocols (<b>FTP</b>, <b>SFTP/SSH</b>, or <b>WebDAV over HTTP/HTTPS</b>). BackupFlow does not route traffic through any intermediate or proxy servers.</p>\n<h3>3.3 Zero Third-Party Analytics or Tracking</h3>\n<p>BackupFlow contains no third-party analytics SDKs, telemetry trackers, crash-reporting SDKs, or advertising frameworks.</p>"
      ],
      [
        "app-store-info",
        "4. App Store & System Information",
        "<p>The only external information associated with the app is standard data processed by Apple through the App Store:</p>\n<ul>\n<li>App purchase and download verification (processed entirely by Apple App Store)</li>\n<li>Aggregated, anonymized crash logs or diagnostics (only if you have opted in to share diagnostics with app developers in iOS Settings)</li>\n<li>Public ratings and reviews you choose to post on the App Store</li>\n</ul>\n<p>This information is governed by Apple's Privacy Policy and cannot be used by us to identify you personally.</p>"
      ],
      [
        "permissions",
        "5. Permissions & Device Access",
        "<ul>\n<li><b>Photo Library Access</b>: Used solely to read new or modified photos and videos (and optionally download originals from iCloud Photos when <i>Download iCloud items if needed</i> is enabled) so they can be backed up to your server.</li>\n<li><b>Files &amp; Folders Access</b>: When you choose <b>Select Folder</b>, BackupFlow uses iOS security-scoped bookmarks solely to read the folder you selected in the Files app.</li>\n<li><b>Local Network &amp; Internet Access</b>: Used exclusively to connect to your configured FTP, SFTP, or WebDAV server on your home Wi-Fi or over the internet.</li>\n<li><b>Background App Refresh</b>: Used with iOS <code>BGTaskScheduler</code> to execute your scheduled backups in the background when conditions (Wi-Fi, power, battery, time window) are met.</li>\n<li><b>Notifications</b>: Used only to inform you of backup completion, errors, or pending scheduled tasks.</li>\n</ul>"
      ],
      [
        "security",
        "6. Data Security & Integrity",
        "<ul>\n<li><b>Encrypted Protocols</b>: Supports encrypted transfers via <b>SFTP (SSH)</b> and <b>WebDAV over HTTPS</b>.</li>\n<li><b>SFTP Host Key Verification</b>: Remembers your SFTP server's SSH fingerprint on first connection and alerts you if the server identity ever changes.</li>\n<li><b>Checksum Verification</b>: Optional <b>Checksum</b> mode verifies that uploaded files arrive on your server intact.</li>\n<li><b>Keychain Protection</b>: Credentials are protected by hardware-backed iOS Keychain encryption.</li>\n</ul>"
      ],
      [
        "third-party",
        "7. Third-Party Services",
        "<p>BackupFlow does not integrate with any third-party cloud, analytics, or advertising services. The app communicates solely with the backup server addresses that you explicitly configure.</p>"
      ],
      [
        "children",
        "8. Children's Privacy",
        "<p>BackupFlow does not knowingly or unknowingly collect personal data from anyone, including children under the age of 13 (or the applicable age in your jurisdiction).</p>"
      ],
      [
        "your-rights",
        "9. Your Rights, Control & Data Reset",
        "<p>Because we do not collect or store any of your personal data on external servers, you hold complete control directly on your iPhone:</p>\n<ul>\n<li>You can view, edit, or delete individual backup tasks and saved servers at any time from the <b>Backup Hub</b>.</li>\n<li>You can clear your backup logs at any time in <b>Backup History</b> or adjust automatic expiration in <b>Settings › History Retention (Days)</b>.</li>\n<li>You can permanently wipe all tasks, history, and saved Keychain passwords from your device at any time by tapping <b>Settings › Reset All Data</b>, or by uninstalling BackupFlow. Files already backed up on your servers are never affected.</li>\n</ul>"
      ],
      [
        "changes",
        "10. Changes to This Privacy Policy",
        "<p>We may update this Privacy Policy from time to time to reflect new app features or legal requirements. Updates will be posted on this page with a revised \"Last updated\" date.</p>"
      ],
      [
        "contact",
        "11. Contact Information",
        "<p>If you have any questions about this Privacy Policy or BackupFlow's privacy practices, you can reach us via <b>Settings › Contact Support</b> in the app or directly at:</p>\n<ul>\n<li><b>Email</b>: <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>Developer</b>: Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. Jurisdiction & Compliance",
        "<p>BackupFlow is designed to comply with global privacy regulations, including the European Union General Data Protection Regulation (<b>GDPR</b>), the Turkish Personal Data Protection Law (<b>KVKK</b>), the California Consumer Privacy Act (<b>CCPA</b>), and Apple App Store privacy guidelines. Because no personal data is collected or processed by us, your privacy is protected by design.</p>"
      ]
    ]
  },
  "tr": {
    "title": "Gizlilik Politikası - BackupFlow",
    "description": "BackupFlow Gizlilik Politikası — iOS'ta yerel öncelikli gizlilik mimarisiyle fotoğraf, video, dosya ve sunucu bilgilerinizin nasıl korunduğunu öğrenin.",
    "h1": "Gizlilik Politikası",
    "updated": "Son güncelleme: Ekim 2026",
    "lead": "BackupFlow, yerel öncelikli gizlilik (local-first privacy) ilkesiyle geliştirilmiştir. Fotoğraflarınız, videolarınız, dosyalarınız ve sunucu şifreleriniz asla bizim sunucularımıza veya üçüncü taraf bulut servislerine gönderilmez.",
    "toc_title": "Bu sayfada",
    "summary_title": "Gizlilik Özeti",
    "summary_text": "BackupFlow'da gizliliğiniz en yüksek önceliktir. Kişisel verilerinizi, fotoğraflarınızı, videolarınızı, dosyalarınızı veya sunucu parolalarınızı toplamıyor, saklamıyor ve bunlara erişmiyoruz. Tüm yedeklemeler doğrudan iPhone'unuzdan kendi sunucunuza aktarılır; kontrol tamamen sizdedir.",
    "sections": [
      [
        "introduction",
        "1. Giriş",
        "<p>BackupFlow'a hoş geldiniz. Gizliliğinizi korumaya ve verilerinizin güvenliğini sağlamaya kararlıyız. Bu Gizlilik Politikası, iOS uygulamamızı ve web sitemizi kullandığınızda verilerinizin nasıl korunduğunu açıklar.</p>\n<p><b>Temel İlke:</b> BackupFlow, <b>yerel öncelikli ve sıfır erişimli (zero-knowledge)</b> bir mimariyle çalışır. Fotoğraflarınız, videolarınız, belgeleriniz ve sunucu kimlik bilgileriniz hiçbir zaman bizim sunucularımıza veya üçüncü taraf bir bulut hizmetine yüklenmez. Tüm veri aktarımı doğrudan iPhone'unuz ile sizin belirlediğiniz sunucu (NAS, ev sunucusu veya kişisel bulut) arasında gerçekleşir.</p>"
      ],
      [
        "not-collected",
        "2. Toplamadığımız Bilgiler",
        "<p>BackupFlow aşağıdaki verilerin hiçbirini <b>toplamaz, saklamaz, işlemez veya paylaşmaz</b>:</p>\n<ul>\n<li>Fotoğraflarınız, videolarınız veya medya üst verileriniz (EXIF/konum vb.)</li>\n<li>iOS Dosyalar uygulamasından seçtiğiniz klasör ve dosyalar</li>\n<li>Sunucu adresleriniz, port numaralarınız, kullanıcı adlarınız veya şifreleriniz</li>\n<li>Yedekleme görevleriniz, zamanlama ayarlarınız veya yedekleme geçmişiniz</li>\n<li>Cihaz kimlikleri, reklam kimlikleri (IDFA) veya kullanım istatistikleri</li>\n<li>IP adresiniz, konum verileriniz veya rehberiniz</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. Verileriniz Nasıl Gizli Kalır?",
        "<h3>3.1 Yerel Veri Depolama ve iOS Anahtarlık (Keychain)</h3>\n<p>Tüm yedekleme görevleriniz, zamanlama tercihleriniz, geçmiş kayıtlarınız ve uygulama ayarlarınız yalnızca iPhone'unuzda yerel olarak saklanır. Sunucu parolalarınız (FTP, SFTP ve WebDAV şifreleri) donanım destekli <b>iOS Keychain (Anahtarlık)</b> içinde şifrelenir ve kendi sunucunuza bağlanmak dışında cihazınızdan asla çıkmaz.</p>\n<h3>3.2 Doğrudan Sunucu İletişimi</h3>\n<p>Yedekleme çalıştığında dosyalarınız standart protokoller (<b>FTP</b>, <b>SFTP/SSH</b> veya <b>HTTP/HTTPS üzerinden WebDAV</b>) kullanılarak doğrudan iPhone'unuzdan kendi sunucunuza aktarılır. Arada hiçbir aracı sunucu bulunmaz.</p>\n<h3>3.3 Üçüncü Taraf Analiz veya Takip Yok</h3>\n<p>BackupFlow içerisinde hiçbir üçüncü taraf analiz aracı, reklam ağı veya kullanıcı takip SDK'sı yer almaz.</p>"
      ],
      [
        "app-store-info",
        "4. App Store ve Sistem Bilgileri",
        "<p>Uygulamayla ilişkili tek dış veri, Apple tarafından App Store üzerinden standart olarak yönetilen bilgilerdir:</p>\n<ul>\n<li>Uygulama indirme, ücretsiz deneme kullanımı ve isteğe bağlı uygulama içi satın alma (BackupFlow Pro Lifetime) doğrulama bilgileri (tamamen Apple StoreKit tarafından işlenir)</li>\n<li>Anonimleştirilmiş çökme raporları (yalnızca iOS ayarlarında geliştiricilerle paylaşmayı seçtiyseniz)</li>\n<li>App Store'da herkese açık olarak yazdığınız puan ve değerlendirmeler</li>\n</ul>\n<p>Bu bilgiler Apple'ın gizlilik politikasına tabidir ve bireysel kullanıcıları kimliklendirmek için tarafımızca kullanılamaz.</p>"
      ],
      [
        "permissions",
        "5. İzinler ve Cihaz Erişimi",
        "<ul>\n<li><b>Fotoğraf Galerisi Erişimi</b>: Yalnızca fotoğraf ve videolarınızı okuyup sunucunuza yedeklemek (ve <i>Gerekirse iCloud öğelerini indir</i> seçeneği açıksa iCloud'daki orijinalleri indirmek) için kullanılır.</li>\n<li><b>Dosyalar ve Klasör Erişimi</b>: <b>Klasör Seç</b> özelliğini kullandığınızda, yalnızca Dosyalar uygulamasında seçtiğiniz klasörü okumak için iOS güvenli yer imleri (security-scoped bookmarks) kullanılır.</li>\n<li><b>Yerel Ağ ve İnternet Erişimi</b>: Yalnızca yapılandırdığınız FTP, SFTP veya WebDAV sunucusuna ev Wi-Fi ağınızdan veya internetten bağlanmak için kullanılır.</li>\n<li><b>Arka Planda Uygulama Yenileme</b>: Belirlediğiniz koşullar (Wi-Fi, şarj, pil, saat aralığı) sağlandığında zamanlanmış yedeklemeleri iOS <code>BGTaskScheduler</code> ile çalıştırmak için kullanılır.</li>\n<li><b>Bildirimler</b>: Yalnızca yedekleme durumu, tamamlanma veya hatalar hakkında sizi bilgilendirmek için kullanılır.</li>\n</ul>"
      ],
      [
        "security",
        "6. Veri Güvenliği ve Bütünlüğü",
        "<ul>\n<li><b>Şifreli Protokoller</b>: <b>SFTP (SSH)</b> ve <b>HTTPS üzerinden WebDAV</b> ile uçtan uca şifreli veri aktarımını destekler.</li>\n<li><b>SFTP Sunucu Kimliği Doğrulama</b>: İlk bağlantıda SFTP sunucunuzun SSH parmak izini kaydeder ve sunucu kimliği değişirse sizi uyarır.</li>\n<li><b>Sağlama Toplamı (Checksum)</b>: İsteğe bağlı <b>Sağlama toplamı</b> özelliği ile yüklenen dosyaların sunucuya eksiksiz ulaştığını doğrular.</li>\n<li><b>Anahtarlık Koruması</b>: Parolalar iOS Keychain şifrelemesiyle korunur.</li>\n</ul>"
      ],
      [
        "third-party",
        "7. Üçüncü Taraf Hizmetler",
        "<p>BackupFlow veri toplama, analiz veya reklam amacıyla hiçbir üçüncü taraf hizmetle entegre değildir. Uygulama yalnızca sizin açıkça tanımladığınız yedekleme sunucularıyla iletişim kurar.</p>"
      ],
      [
        "children",
        "8. Çocukların Gizliliği",
        "<p>BackupFlow, 13 yaş altı çocuklar dahil olmak üzere hiç kimseden kişisel veri toplamaz ve her yaştan kullanıcı için güvenlidir.</p>"
      ],
      [
        "your-rights",
        "9. Haklarınız, Kontrol ve Verileri Sıfırlama",
        "<p>Kişisel verilerinizi toplamadığımız için tüm verilerinizin kontrolü doğrudan kendi cihazınızdadır:</p>\n<ul>\n<li><b>Yedekleme Merkezi</b> üzerinden görevlerinizi ve kayıtlı sunucularınızı istediğiniz an düzenleyebilir veya silebilirsiniz.</li>\n<li><b>Yedek Geçmişi</b> ekranından geçmiş kayıtlarını temizleyebilir veya <b>Ayarlar › Geçmiş Saklama (Gün)</b> ile saklama süresini belirleyebilirsiniz.</li>\n<li><b>Ayarlar › Tüm Verileri Sıfırla</b> seçeneğine dokunarak (veya uygulamayı silerek) tüm görevleri, geçmişi ve kayıtlı parolaları cihazınızdan anında silebilirsiniz. Sunucularınızdaki yedeklenmiş dosyalara dokunulmaz.</li>\n</ul>"
      ],
      [
        "changes",
        "10. Gizlilik Politikasındaki Değişiklikler",
        "<p>Bu Gizlilik Politikasını yeni özellikler veya yasal gereklilikler doğrultusunda zaman zaman güncelleyebiliriz. Yapılan değişiklikler güncellenmiş tarih ile bu sayfada yayınlanır.</p>"
      ],
      [
        "contact",
        "11. İletişim Bilgileri",
        "<p>Bu Gizlilik Politikası hakkında sorularınız için uygulama içindeki <b>Ayarlar › Destek İletişim</b> bölümünden veya doğrudan aşağıdaki bilgilerden bize ulaşabilirsiniz:</p>\n<ul>\n<li><b>E-posta</b>: <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>Geliştirici</b>: Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. Yasal Uyumluluk",
        "<p>BackupFlow; Kişisel Verilerin Korunması Kanunu (<b>KVKK</b>), Avrupa Birliği Genel Veri Koruma Tüzüğü (<b>GDPR</b>), Kaliforniya Tüketici Gizliliği Yasası (<b>CCPA</b>) ve Apple App Store gizlilik standartlarına tam uyumlu olacak şekilde tasarlanmıştır. Hiçbir kişisel veri toplanmadığı için gizliliğiniz tasarım gereği (privacy by design) korunmaktadır.</p>"
      ]
    ]
  },
  "de": {
    "title": "Datenschutzrichtlinie - BackupFlow",
    "description": "BackupFlow Datenschutzrichtlinie – Erfahren Sie, wie BackupFlow Ihre Fotos, Videos, Dateien und Server-Zugangsdaten durch lokalen Datenschutz auf iOS schützt.",
    "h1": "Datenschutzrichtlinie",
    "updated": "Zuletzt aktualisiert: Oktober 2026",
    "lead": "BackupFlow wurde nach dem Prinzip „Local-First Privacy“ entwickelt. Ihre Fotos, Videos, Dateien und Server-Zugangsdaten gelangen niemals auf unsere Server oder in eine fremde Cloud.",
    "toc_title": "Auf dieser Seite",
    "summary_title": "Datenschutz-Zusammenfassung",
    "summary_text": "Bei BackupFlow steht Ihre Privatsphäre an erster Stelle. Wir erheben, speichern oder sehen keinerlei persönliche Daten, Fotos, Videos, Dateien oder Passwörter. Alle Backups werden direkt von Ihrem iPhone auf Ihren eigenen Server übertragen.",
    "sections": [
      [
        "introduction",
        "1. Einleitung",
        "<p>Willkommen bei BackupFlow. Der Schutz Ihrer Privatsphäre und die Sicherheit Ihrer Daten haben für uns höchste Priorität. Diese Datenschutzrichtlinie erläutert, wie BackupFlow mit Daten umgeht, wenn Sie unsere iOS-App und Website nutzen.</p>\n<p><b>Grundprinzip:</b> BackupFlow arbeitet vollständig lokal. Ihre Fotos, Videos, Dokumente und Server-Zugangsdaten werden niemals auf unsere Server oder an Drittanbieter-Clouds übertragen. Alle Übertragungen finden direkt zwischen Ihrem iPhone und Ihrem eigenen Server (NAS, Heimserver oder persönliche Cloud) statt.</p>"
      ],
      [
        "not-collected",
        "2. Daten, die wir NICHT erheben",
        "<p>BackupFlow erhebt, speichert oder überträgt <b>keine</b> der folgenden Informationen:</p>\n<ul>\n<li>Ihre Fotos, Videos oder Medien-Metadaten</li>\n<li>Dateien oder Ordner aus der iOS-Dateien-App</li>\n<li>Serveradressen, Ports, Benutzernamen oder Passwörter</li>\n<li>Backup-Aufgaben, Zeitpläne oder Backup-Verläufe</li>\n<li>Geräte-IDs, Werbe-IDs (IDFA) oder Nutzungsstatistiken</li>\n<li>Ihre IP-Adresse, Standortdaten oder Kontakte</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. Wie Ihre Daten privat bleiben",
        "<h3>3.1 Lokale Speicherung &amp; iOS-Schlüsselbund (Keychain)</h3>\n<p>Alle Aufgaben, Zeitpläne, Verläufe und Einstellungen werden ausschließlich lokal auf Ihrem iPhone gespeichert. Zugangsdaten (FTP-, SFTP- und WebDAV-Passwörter) werden verschlüsselt im <b>iOS-Schlüsselbund (Keychain)</b> abgelegt und verlassen Ihr Gerät nur zur direkten Anmeldung an Ihrem eigenen Server.</p>\n<h3>3.2 Direkte Server-Kommunikation</h3>\n<p>Beim Backup werden Ihre Dateien direkt per <b>FTP</b>, <b>SFTP (SSH)</b> oder <b>WebDAV (HTTP/HTTPS)</b> an Ihren Server gesendet – ohne Zwischenserver.</p>\n<h3>3.3 Keine Analyse- oder Tracking-Dienste</h3>\n<p>BackupFlow enthält keinerlei Analyse-SDKs, Werbenetzwerke oder Tracking-Tools von Drittanbietern.</p>"
      ],
      [
        "app-store-info",
        "4. App Store- und Systeminformationen",
        "<p>Die einzigen externen Informationen sind Standarddaten, die Apple über den App Store abwickelt (Kaufabwicklung, optionale anonymisierte Absturzberichte über iOS-Einstellungen sowie öffentliche App-Store-Rezensionen). Diese Daten unterliegen der Datenschutzrichtlinie von Apple.</p>"
      ],
      [
        "permissions",
        "5. Berechtigungen & Gerätezugriff",
        "<ul>\n<li><b>Fotomediathek</b>: Nur zum Lesen und Sichern Ihrer Fotos und Videos auf Ihrem Server (inkl. optionalem Laden von iCloud-Originalen).</li>\n<li><b>Dateien &amp; Ordner</b>: Beim Tippen auf <b>Ordner auswählen</b> greift BackupFlow nur über geschützte iOS-Lesezeichen auf den von Ihnen gewählten Ordner zu.</li>\n<li><b>Lokales Netzwerk &amp; Internet</b>: Ausschließlich für die Verbindung zu Ihrem FTP-, SFTP- oder WebDAV-Server.</li>\n<li><b>Hintergrundaktualisierung &amp; Mitteilungen</b>: Nur zur Ausführung geplanter Backups über den <code>BGTaskScheduler</code> und für Statusbenachrichtigungen.</li>\n</ul>"
      ],
      [
        "security",
        "6. Datensicherheit & Integrität",
        "<ul>\n<li><b>Verschlüsselung</b>: Unterstützt verschlüsselte Übertragungen per <b>SFTP (SSH)</b> und <b>HTTPS-WebDAV</b>.</li>\n<li><b>SFTP-Serverprüfung</b>: Speichert den SSH-Fingerabdruck Ihres Servers bei der ersten Verbindung und warnt bei Änderungen.</li>\n<li><b>Prüfsumme (Checksum)</b>: Optionale Integritätsprüfung nach dem Upload.</li>\n<li><b>Schlüsselbund-Schutz</b>: Hardwaregestützte Verschlüsselung Ihrer Passwörter im iOS Keychain.</li>\n</ul>"
      ],
      [
        "third-party",
        "7. Dienste von Drittanbietern",
        "<p>BackupFlow integriert keine Drittanbieter-Dienste für Datenerhebung, Analyse oder Werbung und kommuniziert ausschließlich mit den von Ihnen konfigurierten Servern.</p>"
      ],
      [
        "children",
        "8. Datenschutz für Kinder",
        "<p>BackupFlow sammelt von niemandem personenbezogene Daten, auch nicht von Kindern unter 13 Jahren.</p>"
      ],
      [
        "your-rights",
        "9. Ihre Rechte, Kontrolle & Daten zurücksetzen",
        "<p>Sie behalten jederzeit die volle Kontrolle über alle lokalen Daten auf Ihrem iPhone:</p>\n<ul>\n<li>Aufgaben und Server lassen sich jederzeit in der <b>Backup-Zentrale</b> bearbeiten oder löschen.</li>\n<li>Den Verlauf können Sie im <b>Backup-Verlauf</b> leeren oder über <b>Einstellungen › Verlaufsaufbewahrung (Tage)</b> begrenzen.</li>\n<li>Über <b>Einstellungen › Alle Daten zurücksetzen</b> (oder durch Deinstallieren der App) löschen Sie sofort alle Aufgaben, Verläufe und gespeicherten Passwörter von Ihrem Gerät. Dateien auf Ihren Servern bleiben unberührt.</li>\n</ul>"
      ],
      [
        "changes",
        "10. Änderungen dieser Datenschutzrichtlinie",
        "<p>Aktualisierungen dieser Richtlinie werden auf dieser Seite mit einem aktualisierten Datum veröffentlicht.</p>"
      ],
      [
        "contact",
        "11. Kontakt",
        "<p>Bei Fragen erreichen Sie uns über <b>Einstellungen › Support kontaktieren</b> in der App oder per E-Mail:</p>\n<ul>\n<li><b>E-Mail</b>: <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>Entwickler</b>: Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. Rechtskonformität (DSGVO / GDPR)",
        "<p>BackupFlow erfüllt die Anforderungen der Europäischen Datenschutz-Grundverordnung (<b>DSGVO / GDPR</b>), des <b>CCPA</b> sowie weiterer internationaler Datenschutzgesetze durch konsequenten Datenschutz durch Technikgestaltung (Privacy by Design).</p>"
      ]
    ]
  },
  "fr": {
    "title": "Politique de confidentialité - BackupFlow",
    "description": "Politique de confidentialité de BackupFlow — Découvrez comment BackupFlow protège vos photos, vidéos, fichiers et identifiants serveur grâce à une confidentialité 100 % locale sur iOS.",
    "h1": "Politique de confidentialité",
    "updated": "Dernière mise à jour : Octobre 2026",
    "lead": "BackupFlow est conçu selon le principe de confidentialité locale (local-first). Vos photos, vidéos, fichiers et identifiants serveur ne transitent jamais par nos serveurs ni par un cloud tiers.",
    "toc_title": "Sur cette page",
    "summary_title": "Résumé de confidentialité",
    "summary_text": "BackupFlow place votre vie privée au premier plan. Nous ne collectons, ne stockons et n'avons accès à aucune de vos données personnelles, photos, vidéos, fichiers ou mots de passe. Vos sauvegardes vont directement de votre iPhone à votre propre serveur.",
    "sections": [
      [
        "introduction",
        "1. Introduction",
        "<p>Bienvenue sur BackupFlow. Nous nous engageons à protéger votre vie privée. Cette Politique de confidentialité explique comment BackupFlow traite les informations lorsque vous utilisez notre application iOS et notre site web.</p>\n<p><b>Principe fondamental :</b> BackupFlow fonctionne entièrement en local. Vos photos, vidéos, documents et identifiants ne sont jamais envoyés sur nos serveurs ni sur un service cloud tiers. Tous les transferts s'effectuent directement entre votre iPhone et votre propre serveur (NAS, serveur domestique ou cloud personnel).</p>"
      ],
      [
        "not-collected",
        "2. Informations que nous NE collectons PAS",
        "<p>BackupFlow ne collecte, ne stocke et ne partage <b>aucune</b> des données suivantes :</p>\n<ul>\n<li>Vos photos, vidéos ou métadonnées multimédias</li>\n<li>Les fichiers ou dossiers sélectionnés depuis l'app Fichiers</li>\n<li>Les adresses de vos serveurs, ports, noms d'utilisateur ou mots de passe</li>\n<li>Vos tâches de sauvegarde, votre planification ou votre historique</li>\n<li>Les identifiants d'appareil, identifiants publicitaires (IDFA) ou données d'analyse</li>\n<li>Votre adresse IP, votre localisation ou vos contacts</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. Comment vos données restent privées",
        "<h3>3.1 Stockage local et Trousseau iOS (Keychain)</h3>\n<p>Toutes les configurations de tâches, planifications, journaux d'historique et préférences sont stockés localement sur votre iPhone. Vos mots de passe (FTP, SFTP et WebDAV) sont chiffrés dans le <b>Trousseau iOS (Keychain)</b> et ne quittent jamais votre appareil sauf pour s'authentifier auprès de votre serveur.</p>\n<h3>3.2 Transfert direct vers votre serveur</h3>\n<p>Lors d'une sauvegarde, vos fichiers sont transférés directement de votre iPhone vers votre serveur via <b>FTP</b>, <b>SFTP (SSH)</b> ou <b>WebDAV (HTTP/HTTPS)</b>, sans aucun serveur intermédiaire.</p>\n<h3>3.3 Aucune analyse ni pistage tiers</h3>\n<p>BackupFlow n'intègre aucun SDK d'analyse, de télémétrie ou de publicité.</p>"
      ],
      [
        "app-store-info",
        "4. Informations App Store et système",
        "<p>Les seules données externes sont celles gérées directement par Apple via l'App Store (validation d'achat, rapports de plantage anonymisés optionnels d'iOS et avis publics sur l'App Store), soumises à la politique de confidentialité d'Apple.</p>"
      ],
      [
        "permissions",
        "5. Autorisations et accès à l'appareil",
        "<ul>\n<li><b>Photothèque</b> : Utilisée uniquement pour lire et sauvegarder vos photos et vidéos vers votre serveur (y compris le téléchargement optionnel des originaux iCloud).</li>\n<li><b>Fichiers et dossiers</b> : Lorsque vous touchez <b>Sélectionner un dossier</b>, BackupFlow accède uniquement au dossier choisi dans l'app Fichiers.</li>\n<li><b>Réseau local et Internet</b> : Utilisé exclusivement pour se connecter à votre serveur FTP, SFTP ou WebDAV.</li>\n<li><b>Actualisation en arrière-plan et Notifications</b> : Utilisées uniquement pour exécuter les sauvegardes planifiées (<code>BGTaskScheduler</code>) et vous informer de leur état.</li>\n</ul>"
      ],
      [
        "security",
        "6. Sécurité et intégrité des données",
        "<ul>\n<li><b>Protocoles chiffrés</b> : Prise en charge de <b>SFTP (SSH)</b> et <b>WebDAV via HTTPS</b>.</li>\n<li><b>Vérification de clé d'hôte SFTP</b> : Mémorise l'empreinte SSH de votre serveur lors de la première connexion et vous avertit en cas de modification.</li>\n<li><b>Somme de contrôle (Checksum)</b> : Vérification optionnelle de l'intégrité des fichiers envoyés.</li>\n<li><b>Protection Keychain</b> : Chiffrement matériel des mots de passe dans le Trousseau iOS.</li>\n</ul>"
      ],
      [
        "third-party",
        "7. Services tiers",
        "<p>BackupFlow n'utilise aucun service tiers de collecte de données ou de publicité et communique uniquement avec les serveurs que vous configurez.</p>"
      ],
      [
        "children",
        "8. Confidentialité des enfants",
        "<p>BackupFlow ne collecte aucune donnée personnelle auprès de qui que ce soit, y compris des enfants de moins de 13 ans.</p>"
      ],
      [
        "your-rights",
        "9. Vos droits, contrôle et réinitialisation",
        "<p>Vous gardez le contrôle total sur votre appareil :</p>\n<ul>\n<li>Modifiez ou supprimez vos tâches à tout moment depuis le <b>Centre de sauvegarde</b>.</li>\n<li>Effacez l'historique dans <b>Historique des sauvegardes</b> ou ajustez la durée dans <b>Paramètres › Rétention de l'historique (jours)</b>.</li>\n<li>Touchez <b>Paramètres › Réinitialiser toutes les données</b> (ou désinstallez l'application) pour supprimer immédiatement toutes les tâches, l'historique et les mots de passe enregistrés sur cet iPhone. Vos fichiers sur vos serveurs ne sont jamais touchés.</li>\n</ul>"
      ],
      [
        "changes",
        "10. Modifications de cette politique",
        "<p>Toute mise à jour de cette Politique de confidentialité sera publiée sur cette page avec une date actualisée.</p>"
      ],
      [
        "contact",
        "11. Contact",
        "<p>Pour toute question, contactez-nous via <b>Paramètres › Contacter le support</b> dans l'application ou par e-mail :</p>\n<ul>\n<li><b>E-mail</b> : <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>Développeur</b> : Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. Juridiction et conformité (RGPD / GDPR)",
        "<p>BackupFlow respecte le Règlement général sur la protection des données (<b>RGPD / GDPR</b>), le <b>CCPA</b> et les réglementations internationales en matière de vie privée grâce à une protection dès la conception (Privacy by Design).</p>"
      ]
    ]
  },
  "es": {
    "title": "Política de privacidad - BackupFlow",
    "description": "Política de privacidad de BackupFlow — Descubre cómo BackupFlow protege tus fotos, vídeos, archivos y credenciales con privacidad 100 % local en iOS.",
    "h1": "Política de privacidad",
    "updated": "Última actualización: Octubre de 2026",
    "lead": "BackupFlow está diseñado desde cero con privacidad local (local-first). Tus fotos, vídeos, archivos y contraseñas nunca pasan por nuestros servidores ni por nubes de terceros.",
    "toc_title": "En esta página",
    "summary_title": "Resumen de privacidad",
    "summary_text": "BackupFlow tiene tu privacidad como máxima prioridad. No recopilamos, almacenamos ni tenemos acceso a tus datos personales, fotos, vídeos, archivos ni contraseñas. Todas las copias van directamente de tu iPhone a tu propio servidor.",
    "sections": [
      [
        "introduction",
        "1. Introducción",
        "<p>Bienvenido a BackupFlow. Nos comprometemos a proteger tu privacidad y la seguridad de tu información. Esta Política de privacidad explica cómo funciona BackupFlow cuando utilizas nuestra aplicación para iOS y nuestro sitio web.</p>\n<p><b>Principio clave:</b> BackupFlow funciona con una arquitectura estrictamente local. Tus fotos, vídeos, documentos y credenciales nunca se suben a nuestros servidores ni a servicios en la nube de terceros. Todas las transferencias se realizan directamente entre tu iPhone y el servidor que configures (NAS, servidor doméstico o nube personal).</p>"
      ],
      [
        "not-collected",
        "2. Información que NO recopilamos",
        "<p>BackupFlow <b>no</b> recopila, almacena ni comparte ninguno de los siguientes datos:</p>\n<ul>\n<li>Tus fotos, vídeos o metadatos multimedia</li>\n<li>Archivos o carpetas seleccionados desde la app Archivos de iOS</li>\n<li>Direcciones de tus servidores, puertos, nombres de usuario o contraseñas</li>\n<li>Tus tareas de copia de seguridad, horarios o historial de copias</li>\n<li>Identificadores del dispositivo, ID de publicidad (IDFA) o analíticas de uso</li>\n<li>Tu dirección IP, ubicación o contactos</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. Cómo se mantienen privados tus datos",
        "<h3>3.1 Almacenamiento local y Llavero de iOS (Keychain)</h3>\n<p>Todas las tareas, horarios, registros de historial y ajustes se guardan localmente en tu iPhone. Las contraseñas de tus servidores (FTP, SFTP y WebDAV) se cifran en el <b>Llavero de iOS (Keychain)</b> y nunca salen de tu dispositivo salvo para autenticarse directamente con tu propio servidor.</p>\n<h3>3.2 Transferencia directa al servidor</h3>\n<p>Al realizar una copia, tus archivos viajan directamente desde tu iPhone a tu servidor mediante <b>FTP</b>, <b>SFTP (SSH)</b> o <b>WebDAV (HTTP/HTTPS)</b>, sin servidores intermediarios.</p>\n<h3>3.3 Sin analíticas ni rastreadores de terceros</h3>\n<p>BackupFlow no incluye SDKs de analítica, seguimiento ni publicidad de terceros.</p>"
      ],
      [
        "app-store-info",
        "4. Información del App Store y del sistema",
        "<p>La única información externa es la gestionada por Apple en el App Store (validación de compra, informes de fallos anónimos opcionales de iOS y reseñas públicas en el App Store), sujeta a la política de privacidad de Apple.</p>"
      ],
      [
        "permissions",
        "5. Permisos y acceso al dispositivo",
        "<ul>\n<li><b>Biblioteca de fotos</b>: Se usa únicamente para leer y copiar tus fotos y vídeos en tu servidor (incluida la descarga opcional de originales de iCloud).</li>\n<li><b>Archivos y carpetas</b>: Al elegir <b>Seleccionar carpeta</b>, BackupFlow accede únicamente a la carpeta elegida en la app Archivos.</li>\n<li><b>Red local e Internet</b>: Se usa exclusivamente para conectar con tu servidor FTP, SFTP o WebDAV.</li>\n<li><b>Actualización en segundo plano y Notificaciones</b>: Se usan solo para ejecutar copias programadas (<code>BGTaskScheduler</code>) y avisarte de su estado.</li>\n</ul>"
      ],
      [
        "security",
        "6. Seguridad e integridad de los datos",
        "<ul>\n<li><b>Protocolos cifrados</b>: Compatible con transferencias cifradas mediante <b>SFTP (SSH)</b> y <b>WebDAV sobre HTTPS</b>.</li>\n<li><b>Verificación de clave SFTP</b>: Recuerda la huella SSH de tu servidor en la primera conexión y te avisa si cambia.</li>\n<li><b>Suma de verificación (Checksum)</b>: Comprobación opcional de integridad tras la subida.</li>\n<li><b>Protección en el Llavero</b>: Contraseñas protegidas mediante el cifrado del Llavero de iOS.</li>\n</ul>"
      ],
      [
        "third-party",
        "7. Servicios de terceros",
        "<p>BackupFlow no se integra con ningún servicio de terceros para recopilación de datos, analíticas o publicidad, y solo se comunica con los servidores que tú configuras.</p>"
      ],
      [
        "children",
        "8. Privacidad infantil",
        "<p>BackupFlow no recopila información personal de nadie, incluidos menores de 13 años.</p>"
      ],
      [
        "your-rights",
        "9. Tus derechos, control y restablecimiento de datos",
        "<p>Mantienes el control total en tu iPhone:</p>\n<ul>\n<li>Puedes editar o eliminar tareas y servidores en cualquier momento desde el <b>Centro de copias</b>.</li>\n<li>Puedes borrar el historial en <b>Historial de copias</b> o ajustar su duración en <b>Ajustes › Retención de historial (días)</b>.</li>\n<li>Puedes eliminar todas las tareas, el historial y las contraseñas guardadas de tu dispositivo tocando <b>Ajustes › Restablecer todos los datos</b> o desinstalando la app. Los archivos en tus servidores no se ven afectados.</li>\n</ul>"
      ],
      [
        "changes",
        "10. Cambios en esta Política de privacidad",
        "<p>Cualquier cambio en esta política se publicará en esta página con una fecha de actualización revisada.</p>"
      ],
      [
        "contact",
        "11. Información de contacto",
        "<p>Si tienes preguntas, contáctanos desde <b>Ajustes › Contactar soporte</b> en la app o por correo electrónico:</p>\n<ul>\n<li><b>Correo electrónico</b>: <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>Desarrollador</b>: Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. Jurisdicción y cumplimiento (RGPD / CCPA)",
        "<p>BackupFlow cumple con el Reglamento General de Protección de Datos (<b>RGPD / GDPR</b>), la <b>CCPA</b> y demás normativas internacionales de privacidad mediante privacidad por diseño.</p>"
      ]
    ]
  },
  "ru": {
    "title": "Политика конфиденциальности - BackupFlow",
    "description": "Политика конфиденциальности BackupFlow — узнайте, как BackupFlow защищает ваши фото, видео, файлы и пароли серверов благодаря локальной архитектуре на iOS.",
    "h1": "Политика конфиденциальности",
    "updated": "Последнее обновление: Октябрь 2026 г.",
    "lead": "BackupFlow изначально создан по принципу локальной конфиденциальности (local-first). Ваши фото, видео, файлы и пароли от серверов никогда не попадают на наши серверы или в сторонние облака.",
    "toc_title": "На этой странице",
    "summary_title": "Кратко о конфиденциальности",
    "summary_text": "Ваша конфиденциальность — главный приоритет BackupFlow. Мы не собираем, не храним и не имеем доступа к вашим личным данным, фото, видео, файлам или паролям. Все резервные копии передаются напрямую с вашего iPhone на ваш собственный сервер.",
    "sections": [
      [
        "introduction",
        "1. Введение",
        "<p>Добро пожаловать в BackupFlow. Мы уделяем первостепенное внимание защите вашей конфиденциальности. Настоящая Политика конфиденциальности объясняет, как BackupFlow обрабатывает данные при использовании нашего iOS-приложения и веб-сайта.</p>\n<p><b>Ключевой принцип:</b> BackupFlow работает полностью локально. Ваши фотографии, видео, документы и учётные данные серверов никогда не загружаются на наши серверы или в сторонние облачные сервисы. Все файлы передаются напрямую между вашим iPhone и выбранным вами сервером (NAS, домашним сервером или личным облаком).</p>"
      ],
      [
        "not-collected",
        "2. Данные, которые мы НЕ собираем",
        "<p>BackupFlow <b>не</b> собирает, не хранит и не передаёт третьим лицам следующую информацию:</p>\n<ul>\n<li>Ваши фотографии, видеозаписи и метаданные медиафайлов</li>\n<li>Файлы и папки, выбранные в приложении «Файлы» на iOS</li>\n<li>Адреса серверов, порты, имена пользователей и пароли</li>\n<li>Ваши задачи резервного копирования, расписание и журнал истории</li>\n<li>Идентификаторы устройств, рекламные идентификаторы (IDFA) и аналитику использования</li>\n<li>Ваш IP-адрес, геолокацию и контакты</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. Как обеспечивается конфиденциальность",
        "<h3>3.1 Локальное хранение и Связка ключей iOS (Keychain)</h3>\n<p>Все настройки задач, расписания, история и параметры приложения хранятся локально на вашем iPhone. Пароли от серверов (FTP, SFTP и WebDAV) зашифрованы в <b>Связке ключей iOS (Keychain)</b> и никогда не покидают устройство, кроме как для прямой авторизации на вашем сервере.</p>\n<h3>3.2 Прямая передача на сервер</h3>\n<p>Во время резервного копирования файлы передаются напрямую с iPhone на ваш сервер по протоколам <b>FTP</b>, <b>SFTP (SSH)</b> или <b>WebDAV (HTTP/HTTPS)</b> без промежуточных серверов.</p>\n<h3>3.3 Никакой сторонней аналитики и слежки</h3>\n<p>В BackupFlow нет сторонних аналитических SDK, рекламных сетей или трекеров.</p>"
      ],
      [
        "app-store-info",
        "4. Информация App Store и системы",
        "<p>Единственные внешние данные — это стандартная информация, обрабатываемая корпорацией Apple через App Store (подтверждение покупки, опциональные анонимные отчёты о сбоях iOS и публичные отзывы в App Store), которая регулируется политикой конфиденциальности Apple.</p>"
      ],
      [
        "permissions",
        "5. Разрешения и доступ к устройству",
        "<ul>\n<li><b>Доступ к Фото</b>: Используется исключительно для чтения и копирования ваших фото и видео на ваш сервер (включая опциональную загрузку оригиналов из Фото iCloud).</li>\n<li><b>Доступ к Файлам и папкам</b>: При выборе <b>Выбрать папку</b> приложение обращается только к указанной вами папке в приложении «Файлы».</li>\n<li><b>Локальная сеть и Интернет</b>: Используются только для подключения к вашему серверу FTP, SFTP или WebDAV.</li>\n<li><b>Фоновое обновление и Уведомления</b>: Используются только для запуска копий по расписанию (<code>BGTaskScheduler</code>) и уведомлений о статусе.</li>\n</ul>"
      ],
      [
        "security",
        "6. Безопасность и целостность данных",
        "<ul>\n<li><b>Шифрование передачи</b>: Поддержка защищённых протоколов <b>SFTP (SSH)</b> и <b>WebDAV по HTTPS</b>.</li>\n<li><b>Проверка ключа сервера SFTP</b>: Запоминает SSH-отпечаток вашего сервера при первом подключении и предупреждает при его изменении.</li>\n<li><b>Контрольная сумма (Checksum)</b>: Опциональная проверка целостности загруженных файлов.</li>\n<li><b>Защита в Связке ключей</b>: Аппаратное шифрование паролей в iOS Keychain.</li>\n</ul>"
      ],
      [
        "third-party",
        "7. Сторонние сервисы",
        "<p>BackupFlow не интегрируется со сторонними сервисами аналитики или рекламы и обменивается данными только с настроенными вами серверами.</p>"
      ],
      [
        "children",
        "8. Конфиденциальность детей",
        "<p>BackupFlow не собирает персональные данные ни у кого, включая детей младше 13 лет.</p>"
      ],
      [
        "your-rights",
        "9. Ваши права, контроль и сброс данных",
        "<p>Вы полностью контролируете свои данные на iPhone:</p>\n<ul>\n<li>Редактируйте или удаляйте задачи и серверы в любое время в <b>Центре копий</b>.</li>\n<li>Очищайте журнал в разделе <b>История копий</b> или настраивайте срок хранения в <b>Настройки › Хранение истории (дни)</b>.</li>\n<li>Нажмите <b>Настройки › Сбросить все данные</b> (или удалите приложение), чтобы мгновенно удалить все задачи, историю и сохранённые пароли с этого устройства. Файлы на ваших серверах не затрагиваются.</li>\n</ul>"
      ],
      [
        "changes",
        "10. Изменения в Политике конфиденциальности",
        "<p>Любые обновления настоящей Политики будут опубликованы на этой странице с новой датой обновления.</p>"
      ],
      [
        "contact",
        "11. Контактная информация",
        "<p>По всем вопросам вы можете связаться с нами через <b>Настройки › Связаться с поддержкой</b> в приложении или по электронной почте:</p>\n<ul>\n<li><b>Email</b>: <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>Разработчик</b>: Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. Соответствие законодательству (GDPR / CCPA)",
        "<p>BackupFlow полностью соответствует требованиям <b>GDPR</b>, <b>CCPA</b> и других международных норм о защите данных, поскольку не осуществляет сбор персональных данных.</p>"
      ]
    ]
  },
  "ar": {
    "title": "سياسة الخصوصية - BackupFlow",
    "description": "سياسة الخصوصية لتطبيق BackupFlow — تعرّف على كيفية حماية صورك ومقاطع الفيديو وملفاتك وبيانات خادمك بخصوصية محلية كاملة على نظام iOS.",
    "h1": "سياسة الخصوصية",
    "updated": "آخر تحديث: أكتوبر 2026",
    "lead": "صُمم BackupFlow من الأساس وفق مبدأ الخصوصية المحلية أولًا (Local-First Privacy). لا تمر صورك أو مقاطع الفيديو أو ملفاتك أو كلمات مرور خادمك أبدًا عبر خوادمنا أو أي سحابة طرف ثالث.",
    "toc_title": "في هذه الصفحة",
    "summary_title": "ملخص الخصوصية",
    "summary_text": "خصوصيتك هي الأولوية القصوى في BackupFlow. نحن لا نجمع أو نخزن أو نصل إلى بياناتك الشخصية أو صورك أو ملفاتك أو كلمات مرورك. تنتقل جميع النسخ الاحتياطية مباشرة من جهاز iPhone الخاص بك إلى خادمك أنت.",
    "sections": [
      [
        "introduction",
        "1. مقدمة",
        "<p>مرحبًا بك في BackupFlow. نحن ملتزمون بحماية خصوصيتك وأمن بياناتك. توضح سياسة الخصوصية هذه كيف يتعامل BackupFlow مع المعلومات عند استخدام تطبيقنا على iOS وموقعنا الإلكتروني.</p>\n<p><b>المبدأ الأساسي:</b> يعمل BackupFlow ببنية محلية بالكامل. لا تُرفع صورك أو مقاطع الفيديو أو مستنداتك أو بيانات اعتماد الخادم إلى خوادمنا أو أي خدمة سحابية خارجية أبدًا. تتم جميع عمليات النقل مباشرة بين جهاز iPhone الخاص بك والخادم الذي تحدده (NAS أو خادم منزلي أو سحابة شخصية).</p>"
      ],
      [
        "not-collected",
        "2. المعلومات التي لا نجمعها",
        "<p>لا يجمع BackupFlow أو يخزن أو يشارك <b>أيًا</b> مما يلي:</p>\n<ul>\n<li>صورك أو مقاطع الفيديو أو البيانات الوصفية للوسائط</li>\n<li>الملفات أو المجلدات المختارة من تطبيق الملفات في iOS</li>\n<li>عناوين خوادمك أو المنافذ أو أسماء المستخدمين أو كلمات المرور</li>\n<li>مهام النسخ الاحتياطي أو الجداول الزمنية أو سجل النسخ</li>\n<li>معرّفات الجهاز أو معرّفات الإعلانات (IDFA) أو تحليلات الاستخدام</li>\n<li>عنوان IP الخاص بك أو موقعك الجغرافي أو جهات اتصالك</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. كيف تبقى بياناتك خاصة",
        "<h3>3.1 التخزين المحلي وسلسلة مفاتيح iOS (Keychain)</h3>\n<p>تُحفظ جميع إعدادات المهام والجداول والسجلات محليًا على جهاز iPhone الخاص بك. وتُشفّر كلمات مرور الخوادم (FTP وSFTP وWebDAV) داخل <b>سلسلة مفاتيح iOS (Keychain)</b> ولا تغادر جهازك أبدًا إلا عند المصادقة المباشرة مع خادمك.</p>\n<h3>3.2 النقل المباشر إلى الخادم</h3>\n<p>عند تشغيل النسخ الاحتياطي، تنتقل ملفاتك مباشرة من iPhone إلى خادمك عبر <b>FTP</b> أو <b>SFTP (SSH)</b> أو <b>WebDAV (HTTP/HTTPS)</b> دون أي خوادم وسيطة.</p>\n<h3>3.3 لا تحليلات أو تتبع من طرف ثالث</h3>\n<p>لا يحتوي BackupFlow على أي أدوات تحليل أو تتبع أو شبكات إعلانية خارجية.</p>"
      ],
      [
        "app-store-info",
        "4. معلومات App Store والنظام",
        "<p>البيانات الخارجية الوحيدة هي المعلومات القياسية التي تعالجها شركة Apple عبر App Store (تأكيد الشراء، وتقارير الأعطال الاختيارية المجهولة عبر إعدادات iOS، والمراجعات العامة في المتجر)، وهي تخضع لسياسة خصوصية Apple.</p>"
      ],
      [
        "permissions",
        "5. الأذونات والوصول إلى الجهاز",
        "<ul>\n<li><b>مكتبة الصور</b>: تُستخدم فقط لقراءة الصور ومقاطع الفيديو ونسخها احتياطيًا إلى خادمك (بما في ذلك تنزيل النسخ الأصلية من iCloud عند التفعيل).</li>\n<li><b>الملفات والمجلدات</b>: عند اختيار <b>اختر مجلد</b>، يصل التطبيق فقط إلى المجلد الذي حددته في تطبيق الملفات.</li>\n<li><b>الشبكة المحلية والإنترنت</b>: تُستخدم حصريًا للاتصال بخادم FTP أو SFTP أو WebDAV الخاص بك.</li>\n<li><b>التحديث في الخلفية والإشعارات</b>: تُستخدم فقط لتشغيل النسخ المجدولة (<code>BGTaskScheduler</code>) وإبلاغك بحالتها.</li>\n</ul>"
      ],
      [
        "security",
        "6. أمان البيانات وسلامتها",
        "<ul>\n<li><b>بروتوكولات مشفرة</b>: دعم النقل المشفر عبر <b>SFTP (SSH)</b> و<b>WebDAV عبر HTTPS</b>.</li>\n<li><b>التحقق من هوية خادم SFTP</b>: يتذكر بصمة SSH لخادمك عند أول اتصال وينبّهك إذا تغيّرت.</li>\n<li><b>المجموع الاختباري (Checksum)</b>: خيار للتحقق من سلامة الملفات بعد رفعها.</li>\n<li><b>حماية Keychain</b>: تشفير كلمات المرور داخل سلسلة مفاتيح iOS.</li>\n</ul>"
      ],
      [
        "third-party",
        "7. خدمات الطرف الثالث",
        "<p>لا يتكامل BackupFlow مع أي خدمات خارجية لجمع البيانات أو الإعلانات، ويتصل فقط بالخوادم التي تقوم بإعدادها.</p>"
      ],
      [
        "children",
        "8. خصوصية الأطفال",
        "<p>لا يجمع BackupFlow أي بيانات شخصية من أي شخص، بما في ذلك الأطفال دون سن 13 عامًا.</p>"
      ],
      [
        "your-rights",
        "9. حقوقك والتحكم وإعادة تعيين البيانات",
        "<p>تحتفظ بالتحكم الكامل على جهازك:</p>\n<ul>\n<li>يمكنك تعديل أو حذف المهام والخوادم في أي وقت من <b>مركز النسخ الاحتياطي</b>.</li>\n<li>يمكنك مسح السجل من <b>سجل النسخ الاحتياطي</b> أو تعديل مدة الحفظ في <b>الإعدادات › الاحتفاظ بالسجل (أيام)</b>.</li>\n<li>يمكنك مسح جميع المهام والسجلات وكلمات المرور المحفوظة من جهازك فورًا عبر <b>الإعدادات › إعادة تعيين جميع البيانات</b> أو بحذف التطبيق، دون المساس بالملفات الموجودة على خوادمك.</li>\n</ul>"
      ],
      [
        "changes",
        "10. التغييرات على سياسة الخصوصية",
        "<p>قد نحدّث هذه السياسة من وقت لآخر، وسيتم نشر أي تحديث في هذه الصفحة مع تاريخ التحديث الجديد.</p>"
      ],
      [
        "contact",
        "11. معلومات التواصل",
        "<p>لأي استفسار حول الخصوصية، تواصل معنا عبر <b>الإعدادات › اتصل بالدعم</b> داخل التطبيق أو عبر البريد الإلكتروني:</p>\n<ul>\n<li><b>البريد الإلكتروني</b>: <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>المطوّر</b>: Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. الامتثال القانوني (GDPR / CCPA)",
        "<p>يلتزم BackupFlow باللائحة العامة لحماية البيانات (<b>GDPR</b>) وقانون <b>CCPA</b> وقوانين الخصوصية الدولية بفضل تصميمه الذي لا يجمع أي بيانات شخصية.</p>"
      ]
    ]
  },
  "zh": {
    "title": "隐私政策 - BackupFlow",
    "description": "BackupFlow 隐私政策 — 了解 BackupFlow 如何在 iOS 上通过本地优先的隐私架构保护您的照片、视频、文件和服务器凭据。",
    "h1": "隐私政策",
    "updated": "最后更新：2026 年 10 月",
    "lead": "BackupFlow 从底层采用“本地优先隐私 (Local-First Privacy)”架构设计。您的照片、视频、文件和服务器密码绝不会上传到我们的服务器或任何第三方云端。",
    "toc_title": "本页内容",
    "summary_title": "隐私摘要",
    "summary_text": "BackupFlow 将您的隐私放在首位。我们不收集、不存储也无法访问您的个人数据、照片、视频、文件或服务器凭据。所有备份均直接从您的 iPhone 传输至您自己的服务器，由您 100% 掌控。",
    "sections": [
      [
        "introduction",
        "1. 引言",
        "<p>欢迎使用 BackupFlow。我们致力于保护您的隐私和数据安全。本隐私政策说明了当您使用我们的 iOS 应用和网站时，BackupFlow 如何处理信息。</p>\n<p><b>核心原则：</b>BackupFlow 采用严格的<b>本地优先、零知识架构</b>。您的照片、视频、文档和服务器凭据绝不会上传至我们的服务器或任何第三方云服务。所有传输均在您的 iPhone 与您自己配置的服务器（NAS、家庭服务器或私有云）之间直接进行。</p>"
      ],
      [
        "not-collected",
        "2. 我们不收集的信息",
        "<p>BackupFlow <b>不会</b>收集、传输、存储或出售以下任何信息：</p>\n<ul>\n<li>您的照片、视频或媒体元数据</li>\n<li>从 iOS“文件”应用中选择的文件夹或文件</li>\n<li>您的服务器地址、端口、用户名或密码</li>\n<li>您的备份任务、日程安排或备份历史记录</li>\n<li>设备标识符、广告标识符 (IDFA) 或使用情况分析</li>\n<li>您的 IP 地址、地理位置或通讯录</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. 您的数据如何保持私密",
        "<h3>3.1 本地存储与 iOS 钥匙串 (Keychain)</h3>\n<p>所有备份任务配置、计划、历史记录和应用设置均仅保存在您的 iPhone 本地。服务器凭据（FTP、SFTP 和 WebDAV 密码）加密存储在硬件级保护的 <b>iOS 钥匙串 (Keychain)</b> 中，除直接向您自己的服务器认证外，绝不会离开您的设备。</p>\n<h3>3.2 设备到服务器直接传输</h3>\n<p>执行备份时，您的文件通过标准协议（<b>FTP</b>、<b>SFTP/SSH</b> 或 <b>HTTP/HTTPS WebDAV</b>）直接从 iPhone 传输到您指定的服务器，不经过任何中转服务器。</p>\n<h3>3.3 零第三方分析或跟踪</h3>\n<p>BackupFlow 不包含任何第三方统计分析 SDK、遥测跟踪器或广告框架。</p>"
      ],
      [
        "app-store-info",
        "4. App Store 与系统信息",
        "<p>与应用关联的唯一外部信息是由 Apple 通过 App Store 按标准处理的数据（购买验证、您在 iOS 设置中选择共享的匿名崩溃诊断日志，以及您在 App Store 公开发布的评分与评价），这些信息受 Apple 隐私政策约束。</p>"
      ],
      [
        "permissions",
        "5. 权限与设备访问",
        "<ul>\n<li><b>照片图库访问权限</b>：仅用于读取照片和视频并备份到您的服务器（包括在开启<i>需要时下载 iCloud 项目</i>时下载 iCloud 原片）。</li>\n<li><b>文件与文件夹访问权限</b>：当您轻点<b>选择文件夹</b>时，BackupFlow 仅通过 iOS 安全书签读取您在“文件”应用中选择的文件夹。</li>\n<li><b>本地网络与互联网访问权限</b>：仅用于连接您配置的 FTP、SFTP 或 WebDAV 服务器。</li>\n<li><b>后台应用刷新与通知</b>：仅用于通过 <code>BGTaskScheduler</code> 执行计划备份并通知您备份状态。</li>\n</ul>"
      ],
      [
        "security",
        "6. 数据安全与完整性",
        "<ul>\n<li><b>加密传输协议</b>：支持通过 <b>SFTP (SSH)</b> 和 <b>HTTPS WebDAV</b> 进行加密传输。</li>\n<li><b>SFTP 主机密钥验证</b>：首次连接时记住服务器的 SSH 指纹，若服务器身份发生变化会立即向您发出警告。</li>\n<li><b>校验和验证 (Checksum)</b>：可选的<b>校验和</b>功能可在上传后验证服务器上的文件完整性。</li>\n<li><b>钥匙串保护</b>：密码受 iOS 钥匙串硬件加密保护。</li>\n</ul>"
      ],
      [
        "third-party",
        "7. 第三方服务",
        "<p>BackupFlow 不集成任何用于数据收集、分析或广告的第三方服务，应用仅与您明确配置的备份服务器通信。</p>"
      ],
      [
        "children",
        "8. 儿童隐私",
        "<p>BackupFlow 不会收集任何人的个人信息，包括 13 岁以下的儿童。</p>"
      ],
      [
        "your-rights",
        "9. 您的权利、控制与重置所有数据",
        "<p>您在 iPhone 上拥有对数据的完全控制权：</p>\n<ul>\n<li>随时在<b>备份中心</b>中查看、编辑或删除备份任务和已保存的服务器。</li>\n<li>随时在<b>备份历史</b>中清空记录，或在<b>设置 › 历史记录保留期（天）</b>中调整保留天数。</li>\n<li>随时轻点<b>设置 › 重置所有数据</b>（或卸载应用）以永久清除设备上的所有任务、历史记录和已保存的钥匙串密码。您服务器上已备份的文件不会受到任何影响。</li>\n</ul>"
      ],
      [
        "changes",
        "10. 隐私政策的变更",
        "<p>我们可能会不时更新本隐私政策，任何变更都将在此页面发布并更新“最后更新”日期。</p>"
      ],
      [
        "contact",
        "11. 联系方式",
        "<p>如对本隐私政策有任何疑问，您可以通过应用内的<b>设置 › 联系支持</b>或以下方式联系我们：</p>\n<ul>\n<li><b>电子邮件</b>：<a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>开发者</b>：Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. 适用法律与合规性 (GDPR / CCPA)",
        "<p>BackupFlow 遵循欧盟《通用数据保护条例》(<b>GDPR</b>)、加州消费者隐私法案 (<b>CCPA</b>) 及全球主要隐私法规的“默认隐私保护 (Privacy by Design)”原则。</p>"
      ]
    ]
  },
  "ko": {
    "title": "개인정보 처리방침 - BackupFlow",
    "description": "BackupFlow 개인정보 처리방침 — iOS에서 로컬 우선 개인정보 보호 설계를 통해 사진, 동영상, 파일 및 서버 자격 증명을 안전하게 보호하는 방법을 안내합니다.",
    "h1": "개인정보 처리방침",
    "updated": "최종 업데이트: 2026년 10월",
    "lead": "BackupFlow는 로컬 우선 개인정보 보호(Local-First Privacy) 원칙으로 설계되었습니다. 사진, 동영상, 파일 및 서버 비밀번호는 당사 서버나 타사 클라우드로 절대 전송되지 않습니다.",
    "toc_title": "이 페이지에서",
    "summary_title": "개인정보 보호 요약",
    "summary_text": "BackupFlow는 사용자의 개인정보 보호를 최우선으로 합니다. 당사는 개인 데이터, 사진, 동영상, 파일 또는 서버 비밀번호를 수집·저장하거나 열람하지 않습니다. 모든 백업은 iPhone에서 사용자의 서버로 직접 전송됩니다.",
    "sections": [
      [
        "introduction",
        "1. 개요",
        "<p>BackupFlow에 오신 것을 환영합니다. 당사는 사용자의 개인정보와 데이터 보안을 철저히 보호합니다. 본 개인정보 처리방침은 iOS 앱과 웹사이트 이용 시 정보가 어떻게 처리되는지 설명합니다.</p>\n<p><b>핵심 원칙:</b> BackupFlow는 철저한 <b>로컬 우선(Local-First) 아키텍처</b>로 작동합니다. 사진, 동영상, 문서 및 서버 로그인 정보는 당사 서버나 제3자 클라우드에 업로드되지 않으며, iPhone과 사용자가 지정한 서버(NAS, 홈 서버, 개인 클라우드) 간에 직접 전송됩니다.</p>"
      ],
      [
        "not-collected",
        "2. 수집하지 않는 정보",
        "<p>BackupFlow는 다음 정보를 <b>절대 수집, 저장, 전송 또는 판매하지 않습니다</b>:</p>\n<ul>\n<li>사진, 동영상 및 미디어 메타데이터</li>\n<li>iOS 파일 앱에서 선택한 파일 및 폴더</li>\n<li>서버 주소, 포트, 사용자 이름 및 비밀번호</li>\n<li>백업 작업, 스케줄 설정 및 백업 기록</li>\n<li>기기 식별자, 광고 ID(IDFA) 및 사용 분석 데이터</li>\n<li>IP 주소, 위치 정보 및 연락처</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. 데이터 보호 방식",
        "<h3>3.1 로컬 저장소 및 iOS 키체인(Keychain)</h3>\n<p>모든 백업 작업, 스케줄, 기록 및 앱 설정은 iPhone 내부에만 저장됩니다. 서버 비밀번호(FTP, SFTP, WebDAV)는 하드웨어 암호화가 적용된 <b>iOS 키체인(Keychain)</b>에 안전하게 저장되며, 사용자의 서버에 직접 로그인할 때를 제외하고 기기 외부로 나가지 않습니다.</p>\n<h3>3.2 기기-서버 간 직접 전송</h3>\n<p>백업 실행 시 모든 파일은 중간 서버 없이 <b>FTP</b>, <b>SFTP(SSH)</b> 또는 <b>WebDAV(HTTP/HTTPS)</b> 프로토콜을 통해 iPhone에서 사용자의 서버로 직접 전송됩니다.</p>\n<h3>3.3 타사 분석 및 추적 없음</h3>\n<p>BackupFlow에는 타사 분석 SDK, 원격 측정 추적기 또는 광고 프레임워크가 포함되어 있지 않습니다.</p>"
      ],
      [
        "app-store-info",
        "4. App Store 및 시스템 정보",
        "<p>앱과 관련된 유일한 외부 데이터는 Apple이 App Store를 통해 처리하는 표준 정보(구매 확인, iOS 설정에서 공유에 동의한 익명 충돌 로그, 공개 App Store 리뷰)뿐이며, 이는 Apple의 개인정보 처리방침에 따라 관리됩니다.</p>"
      ],
      [
        "permissions",
        "5. 권한 및 기기 접근",
        "<ul>\n<li><b>사진 보관함 접근</b>: 사진과 동영상을 읽어 서버로 백업(및 <i>필요한 경우 iCloud 항목 다운로드</i> 활성화 시 iCloud 원본 다운로드)하기 위해서만 사용됩니다.</li>\n<li><b>파일 및 폴더 접근</b>: <b>폴더 선택</b> 시 iOS 보안 북마크를 통해 사용자가 선택한 폴더만 읽습니다.</li>\n<li><b>로컬 네트워크 및 인터넷 접근</b>: 설정한 FTP, SFTP 또는 WebDAV 서버에 연결하기 위해서만 사용됩니다.</li>\n<li><b>백그라운드 앱 새로 고침 및 알림</b>: 예약된 백업 실행(<code>BGTaskScheduler</code>) 및 백업 상태 알림에만 사용됩니다.</li>\n</ul>"
      ],
      [
        "security",
        "6. 데이터 보안 및 무결성",
        "<ul>\n<li><b>암호화 전송</b>: <b>SFTP(SSH)</b> 및 <b>HTTPS 기반 WebDAV</b> 암호화 전송을 지원합니다.</li>\n<li><b>SFTP 호스트 키 확인</b>: 첫 연결 시 서버의 SSH 지문을 기억하고 변경 시 경고합니다.</li>\n<li><b>체크섬(Checksum) 확인</b>: 업로드된 파일이 손상 없이 도착했는지 확인하는 체크섬 옵션을 제공합니다.</li>\n<li><b>키체인 보호</b>: iOS 키체인을 통한 비밀번호 암호화 저장.</li>\n</ul>"
      ],
      [
        "third-party",
        "7. 제3자 서비스",
        "<p>BackupFlow는 데이터 수집, 분석 또는 광고를 위한 어떠한 제3자 서비스와도 연동하지 않으며 사용자가 설정한 백업 서버와만 통신합니다.</p>"
      ],
      [
        "children",
        "8. 아동의 개인정보 보호",
        "<p>BackupFlow는 만 13세 미만 아동을 포함해 누구로부터도 개인정보를 수집하지 않습니다.</p>"
      ],
      [
        "your-rights",
        "9. 사용자의 권리, 제어 및 데이터 초기화",
        "<p>사용자는 iPhone에서 모든 데이터를 직접 제어할 수 있습니다:</p>\n<ul>\n<li><b>백업 허브</b>에서 언제든지 작업과 저장된 서버를 편집하거나 삭제할 수 있습니다.</li>\n<li><b>백업 기록</b>에서 기록을 지우거나 <b>설정 › 기록 보관 기간(일)</b>에서 보관 기간을 조정할 수 있습니다.</li>\n<li><b>설정 › 모든 데이터 초기화</b>를 탭하거나 앱을 삭제하여 기기의 모든 작업, 기록 및 저장된 비밀번호를 즉시 삭제할 수 있습니다(서버의 파일은 유지됨).</li>\n</ul>"
      ],
      [
        "changes",
        "10. 개인정보 처리방침 변경",
        "<p>본 방침이 업데이트될 경우 변경된 최종 업데이트 날짜와 함께 이 페이지에 게시됩니다.</p>"
      ],
      [
        "contact",
        "11. 문의처",
        "<p>문의 사항이 있으시면 앱 내 <b>설정 › 지원 문의</b> 또는 아래 이메일로 연락해 주세요:</p>\n<ul>\n<li><b>이메일</b>: <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>개발자</b>: Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. 법적 준수 (GDPR / CCPA)",
        "<p>BackupFlow는 개인정보를 수집하지 않는 설계(Privacy by Design)를 통해 <b>GDPR</b>, <b>CCPA</b> 및 각국의 개인정보 보호 법규를 준수합니다.</p>"
      ]
    ]
  },
  "ja": {
    "title": "プライバシーポリシー - BackupFlow",
    "description": "BackupFlow プライバシーポリシー — iOSのローカルファースト設計により、写真・ビデオ・ファイル・サーバー認証情報をどのように保護しているかをご説明します。",
    "h1": "プライバシーポリシー",
    "updated": "最終更新日：2026年10月",
    "lead": "BackupFlowは「ローカルファースト・プライバシー」の原則に基づいて設計されています。あなたの写真、ビデオ、ファイル、サーバーのパスワードが当社のサーバーや他社クラウドに送信されることは一切ありません。",
    "toc_title": "このページの内容",
    "summary_title": "プライバシーの概要",
    "summary_text": "BackupFlowはお客様のプライバシーを最優先に設計されています。当社が個人データ、写真、ビデオ、ファイル、またはサーバーの認証情報を収集・保存・閲覧することは一切ありません。すべてのバックアップはiPhoneからご自身のサーバーへ直接転送されます。",
    "sections": [
      [
        "introduction",
        "1. はじめに",
        "<p>BackupFlowへようこそ。私たちはお客様のプライバシーとデータの安全性を守ることをお約束します。本プライバシーポリシーでは、iOSアプリおよびウェブサイトをご利用いただく際の情報の取り扱いについて説明します。</p>\n<p><b>基本原則：</b>BackupFlowは完全な<b>ローカルファースト・ゼロ知識アーキテクチャ</b>で動作します。写真、ビデオ、書類、サーバー認証情報が当社のサーバーや第三者のクラウドサービスにアップロードされることはありません。すべての転送はお使いのiPhoneとご自身で設定したサーバー（NAS、自宅サーバー、プライベートクラウド）の間で直接行われます。</p>"
      ],
      [
        "not-collected",
        "2. 当社が収集しない情報",
        "<p>BackupFlowは以下の情報を<b>一切収集、保存、送信、販売しません</b>：</p>\n<ul>\n<li>写真、ビデオ、およびメディアのメタデータ</li>\n<li>iOSの「ファイル」アプリから選択されたファイルやフォルダ</li>\n<li>サーバーのアドレス、ポート番号、ユーザー名、パスワード</li>\n<li>バックアップタスク、スケジュール、バックアップ履歴</li>\n<li>デバイス識別子、広告識別子（IDFA）、利用状況の分析データ</li>\n<li>IPアドレス、位置情報、連絡先</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. データのプライバシーが守られる仕組み",
        "<h3>3.1 ローカル保存とiOSキーチェーン（Keychain）</h3>\n<p>すべてのタスク設定、スケジュール、履歴、アプリ設定はiPhone内にのみローカル保存されます。サーバーのパスワード（FTP、SFTP、WebDAV）はハードウェア暗号化された<b>iOSキーチェーン（Keychain）</b>に保存され、ご自身のサーバーへ直接認証する際を除きデバイス外へ出ることはありません。</p>\n<h3>3.2 サーバーへの直接転送</h3>\n<p>バックアップ実行時、ファイルは中継サーバーを介さず、<b>FTP</b>、<b>SFTP（SSH）</b>、または<b>WebDAV（HTTP/HTTPS）</b>でご自身のサーバーへ直接転送されます。</p>\n<h3>3.3 第三者の分析・追跡ツールなし</h3>\n<p>BackupFlowにはサードパーティ製の分析SDK、トラッキングツール、広告フレームワークは一切含まれていません。</p>"
      ],
      [
        "app-store-info",
        "4. App Storeおよびシステム情報",
        "<p>本アプリに関連する唯一の外部情報は、AppleがApp Storeを通じて標準的に処理する情報（購入確認、iOS設定で共有を許可した場合の匿名クラッシュログ、公開レビュー）のみであり、Appleのプライバシーポリシーに従って管理されます。</p>"
      ],
      [
        "permissions",
        "5. 権限とデバイスへのアクセス",
        "<ul>\n<li><b>写真ライブラリへのアクセス</b>：写真やビデオを読み取り、サーバーへバックアップするため（および<i>必要に応じてiCloud項目をダウンロード</i>が有効な場合にiCloudからオリジナルを取得するため）だけに使用されます。</li>\n<li><b>ファイルとフォルダへのアクセス</b>：<b>フォルダを選択</b>を使用際、「ファイル」アプリで選択されたフォルダのみを読み取ります。</li>\n<li><b>ローカルネットワークとインターネット</b>：設定されたFTP、SFTP、WebDAVサーバーへの接続にのみ使用されます。</li>\n<li><b>バックグラウンド更新と通知</b>：スケジュールされたバックアップの実行（<code>BGTaskScheduler</code>）と完了・エラー通知にのみ使用されます。</li>\n</ul>"
      ],
      [
        "security",
        "6. データの 보안と整合性",
        "<ul>\n<li><b>暗号化通信</b>：<b>SFTP（SSH）</b>および<b>HTTPS WebDAV</b>による暗号化転送をサポートしています。</li>\n<li><b>SFTPホスト鍵の検証</b>：初回接続時にサーバーのSSHフィンガープリントを記憶し、変更があった場合は警告します。</li>\n<li><b>チェックサム検証（Checksum）</b>：アップロード後にファイルの整合性を検証するオプションを備えています。</li>\n<li><b>キーチェーン保護</b>：iOSキーチェーンによるパスワードの安全な暗号化保管。</li>\n</ul>"
      ],
      [
        "third-party",
        "7. 第三者サービス",
        "<p>BackupFlowはデータ収集、分析、広告のための第三者サービスとは一切連携せず、お客様が設定したサーバーとのみ通信します。</p>"
      ],
      [
        "children",
        "8. お子様のプライバシー",
        "<p>BackupFlowは13歳未満のお子様を含め、いかなる利用者からも個人情報を収集しません。</p>"
      ],
      [
        "your-rights",
        "9. お客様の権利・管理・データのリセット",
        "<p>すべてのデータはお使いのiPhone上で完全に管理できます：</p>\n<ul>\n<li><b>バックアップハブ</b>からいつでもタスクや保存済みサーバーを編集・削除できます。</li>\n<li><b>バックアップ履歴</b>から履歴を消去したり、<b>設定 › 履歴保持期間（日）</b>で保存日数を変更したりできます。</li>\n<li><b>設定 › すべてのデータをリセット</b>をタップ（またはアプリをアンインストール）すると、すべてのタスク、履歴、保存済みパスワードをデバイスから即座に削除できます。サーバー上のファイルには影響しません。</li>\n</ul>"
      ],
      [
        "changes",
        "10. プライバシーポリシーの変更",
        "<p>本ポリシーを更新した場合は、改訂日とともに本ページに掲載します。</p>"
      ],
      [
        "contact",
        "11. お問い合わせ先",
        "<p>ご質問がある場合は、アプリ内の<b>設定 › サポートに連絡</b>またはメールにてお問い合わせください：</p>\n<ul>\n<li><b>メール</b>：<a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>開発者</b>：Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. 法令遵守（GDPR / CCPA）",
        "<p>BackupFlowは個人データを収集しない設計（Privacy by Design）により、<b>GDPR</b>、<b>CCPA</b>および各国のプライバシー法規に準拠しています。</p>"
      ]
    ]
  },
  "pt": {
    "title": "Política de Privacidade - BackupFlow",
    "description": "Política de Privacidade do BackupFlow — Saiba como o BackupFlow protege suas fotos, vídeos, arquivos e credenciais com privacidade 100% local no iOS.",
    "h1": "Política de Privacidade",
    "updated": "Última atualização: Outubro de 2026",
    "lead": "O BackupFlow foi construído desde o início com privacidade local (local-first). Suas fotos, vídeos, arquivos e senhas de servidor nunca passam pelos nossos servidores nem por nuvens de terceiros.",
    "toc_title": "Nesta página",
    "summary_title": "Resumo de Privacidade",
    "summary_text": "O BackupFlow tem a sua privacidade como prioridade máxima. Não coletamos, armazenamos nem temos acesso aos seus dados pessoais, fotos, vídeos, arquivos ou senhas. Todos os backups vão diretamente do seu iPhone para o seu próprio servidor.",
    "sections": [
      [
        "introduction",
        "1. Introdução",
        "<p>Bem-vindo ao BackupFlow. Estamos comprometidos em proteger sua privacidade e garantir a segurança dos seus dados. Esta Política de Privacidade explica como o BackupFlow lida com informações quando você usa nosso aplicativo para iOS e nosso site.</p>\n<p><b>Princípio Fundamental:</b> O BackupFlow opera com uma arquitetura estritamente local. Suas fotos, vídeos, documentos e credenciais de servidor nunca são enviados para nossos servidores ou serviços de nuvem de terceiros. Todas as transferências ocorrem diretamente entre o seu iPhone e o servidor configurado por você (NAS, servidor doméstico ou nuvem pessoal).</p>"
      ],
      [
        "not-collected",
        "2. Informações que NÃO Coletamos",
        "<p>O BackupFlow <b>não</b> coleta, armazena, transmite ou vende nenhum dos seguintes dados:</p>\n<ul>\n<li>Suas fotos, vídeos ou metadados de mídia</li>\n<li>Arquivos ou pastas selecionados no app Arquivos do iOS</li>\n<li>Endereços de servidores, portas, nomes de usuário ou senhas</li>\n<li>Suas tarefas de backup, agendamentos ou histórico de backups</li>\n<li>Identificadores do dispositivo, IDs de publicidade (IDFA) ou análises de uso</li>\n<li>Seu endereço IP, localização ou contatos</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. Como Seus Dados Permanecem Privados",
        "<h3>3.1 Armazenamento Local e Chaves do iOS (Keychain)</h3>\n<p>Todas as configurações de tarefas, agendamentos, histórico e preferências ficam armazenados localmente no seu iPhone. As senhas dos seus servidores (FTP, SFTP e WebDAV) são criptografadas nas <b>Chaves do iOS (Keychain)</b> e nunca saem do aparelho, exceto para autenticar diretamente no seu servidor.</p>\n<h3>3.2 Transferência Direta para o Servidor</h3>\n<p>Durante o backup, seus arquivos são transferidos diretamente do iPhone para o seu servidor usando <b>FTP</b>, <b>SFTP (SSH)</b> ou <b>WebDAV (HTTP/HTTPS)</b>, sem servidores intermediários.</p>\n<h3>3.3 Sem Análises ou Rastreadores de Terceiros</h3>\n<p>O BackupFlow não inclui SDKs de análise, rastreamento ou publicidade de terceiros.</p>"
      ],
      [
        "app-store-info",
        "4. Informações da App Store e do Sistema",
        "<p>As únicas informações externas são os dados padrão processados pela Apple na App Store (confirmação de compra, relatórios opcionais e anônimos de falhas do iOS e avaliações públicas na App Store), regidos pela política de privacidade da Apple.</p>"
      ],
      [
        "permissions",
        "5. Permissões e Acesso ao Dispositivo",
        "<ul>\n<li><b>Biblioteca de Fotos</b>: Usada exclusivamente para ler e fazer backup de suas fotos e vídeos no seu servidor (incluindo o download opcional de originais do iCloud).</li>\n<li><b>Arquivos e Pastas</b>: Ao tocar em <b>Selecionar pasta</b>, o BackupFlow acessa apenas a pasta escolhida no app Arquivos.</li>\n<li><b>Rede Local e Internet</b>: Usadas exclusivamente para conectar ao seu servidor FTP, SFTP ou WebDAV.</li>\n<li><b>Atualização em Segundo Plano e Notificações</b>: Usadas apenas para executar backups agendados (<code>BGTaskScheduler</code>) e informar o status das tarefas.</li>\n</ul>"
      ],
      [
        "security",
        "6. Segurança e Integridade dos Dados",
        "<ul>\n<li><b>Protocolos Criptografados</b>: Suporte a transferências seguras via <b>SFTP (SSH)</b> e <b>WebDAV sobre HTTPS</b>.</li>\n<li><b>Verificação de Chave SFTP</b>: Memoriza a impressão digital SSH do servidor na primeira conexão e alerta caso ela mude.</li>\n<li><b>Soma de Verificação (Checksum)</b>: Verificação opcional de integridade dos arquivos enviados.</li>\n<li><b>Proteção no Keychain</b>: Senhas protegidas por criptografia de hardware nas Chaves do iOS.</li>\n</ul>"
      ],
      [
        "third-party",
        "7. Serviços de Terceiros",
        "<p>O BackupFlow não se integra a nenhum serviço de terceiros para coleta de dados, análise ou publicidade, comunicando-se apenas com os servidores que você configura.</p>"
      ],
      [
        "children",
        "8. Privacidade Infantil",
        "<p>O BackupFlow não coleta dados pessoais de ninguém, incluindo crianças menores de 13 anos.</p>"
      ],
      [
        "your-rights",
        "9. Seus Direitos, Controle e Redefinição de Dados",
        "<p>Você mantém controle total diretamente no seu iPhone:</p>\n<ul>\n<li>Edite ou exclua tarefas e servidores a qualquer momento na <b>Central de backup</b>.</li>\n<li>Limpe os registros no <b>Histórico de Backup</b> ou ajuste o prazo em <b>Configurações › Retenção de Histórico (Dias)</b>.</li>\n<li>Apague todas as tarefas, histórico e senhas salvas deste dispositivo a qualquer momento tocando em <b>Configurações › Redefinir Todos os Dados</b> ou desinstalando o app. Os arquivos nos seus servidores nunca são afetados.</li>\n</ul>"
      ],
      [
        "changes",
        "10. Alterações nesta Política de Privacidade",
        "<p>Eventuais atualizações desta política serão publicadas nesta página com a data de revisão atualizada.</p>"
      ],
      [
        "contact",
        "11. Informações de Contato",
        "<p>Em caso de dúvidas, entre em contato por <b>Configurações › Contatar Suporte</b> no app ou pelo e-mail:</p>\n<ul>\n<li><b>E-mail</b>: <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>Desenvolvedor</b>: Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. Jurisdição e Conformidade (GDPR / LGPD / CCPA)",
        "<p>O BackupFlow está em conformidade com o <b>GDPR</b> (União Europeia), a <b>LGPD</b> (Brasil), o <b>CCPA</b> (Califórnia) e demais legislações internacionais de proteção de dados por não coletar dados pessoais.</p>"
      ]
    ]
  },
  "hi": {
    "title": "गोपनीयता नीति - BackupFlow",
    "description": "BackupFlow गोपनीयता नीति — जानें कि BackupFlow iOS पर लोकल-फ़र्स्ट प्राइवेसी के साथ आपकी फ़ोटो, वीडियो, फ़ाइलों और सर्वर पासवर्ड की सुरक्षा कैसे करता है।",
    "h1": "गोपनीयता नीति",
    "updated": "अंतिम अपडेट: अक्टूबर 2026",
    "lead": "BackupFlow को लोकल-फ़र्स्ट प्राइवेसी (Local-First Privacy) के सिद्धांत पर बनाया गया है। आपकी फ़ोटो, वीडियो, फ़ाइलें और सर्वर पासवर्ड कभी भी हमारे सर्वर या किसी थर्ड-पार्टी क्लाउड पर नहीं जाते।",
    "toc_title": "इस पेज पर",
    "summary_title": "गोपनीयता सारांश",
    "summary_text": "BackupFlow में आपकी गोपनीयता सर्वोच्च प्राथमिकता है। हम आपका व्यक्तिगत डेटा, फ़ोटो, वीडियो, फ़ाइलें या सर्वर पासवर्ड एकत्र, संग्रहीत या एक्सेस नहीं करते हैं। हर बैकअप सीधे आपके iPhone से आपके अपने सर्वर पर जाता है।",
    "sections": [
      [
        "introduction",
        "1. परिचय",
        "<p>BackupFlow में आपका स्वागत है। हम आपकी गोपनीयता और डेटा सुरक्षा के लिए प्रतिबद्ध हैं। यह गोपनीयता नीति बताती है कि जब आप हमारे iOS ऐप और वेबसाइट का उपयोग करते हैं तो BackupFlow जानकारी को कैसे संभालता है।</p>\n<p><b>मुख्य सिद्धांत:</b> BackupFlow पूरी तरह से <b>लोकल-फ़र्स्ट आर्किटेक्चर</b> पर काम करता है। आपकी फ़ोटो, वीडियो, दस्तावेज़ और सर्वर क्रेडेंशियल कभी भी हमारे सर्वर या किसी तीसरे पक्ष की क्लाउड सेवा पर अपलोड नहीं किए जाते हैं। सभी ट्रांसफ़र सीधे आपके iPhone और आपके द्वारा सेट किए गए सर्वर (NAS, होम सर्वर या निजी क्लाउड) के बीच होते हैं।</p>"
      ],
      [
        "not-collected",
        "2. जानकारी जो हम एकत्र नहीं करते",
        "<p>BackupFlow निम्नलिखित में से कोई भी डेटा <b>एकत्र, संग्रहीत या साझा नहीं करता है</b>:</p>\n<ul>\n<li>आपकी फ़ोटो, वीडियो या मीडिया मेटाडेटा</li>\n<li>iOS Files ऐप से चुनी गई फ़ाइलें या फ़ोल्डर</li>\n<li>आपके सर्वर का पता, पोर्ट, उपयोगकर्ता नाम या पासवर्ड</li>\n<li>आपके बैकअप टास्क, शेड्यूल या बैकअप इतिहास</li>\n<li>डिवाइस आईडी, विज्ञापन आईडी (IDFA) या उपयोग एनालिटिक्स</li>\n<li>आपका IP पता, लोकेशन या कॉन्टैक्ट्स</li>\n</ul>"
      ],
      [
        "how-data-stays-private",
        "3. आपका डेटा कैसे सुरक्षित रहता है",
        "<h3>3.1 लोकल स्टोरेज और iOS कीचेन (Keychain)</h3>\n<p>सभी बैकअप टास्क, शेड्यूल, इतिहास और ऐप सेटिंग्स आपके iPhone पर लोकल रूप से सहेजी जाती हैं। सर्वर पासवर्ड (FTP, SFTP और WebDAV) <b>iOS कीचेन (Keychain)</b> में एन्क्रिप्टेड रहते हैं और आपके सर्वर से सीधे कनेक्ट होने के अलावा कभी आपके डिवाइस से बाहर नहीं जाते।</p>\n<h3>3.2 सीधे सर्वर पर ट्रांसफ़र</h3>\n<p>बैकअप चलते समय आपकी फ़ाइलें बिना किसी बिचौलिए सर्वर के <b>FTP</b>, <b>SFTP (SSH)</b> या <b>WebDAV (HTTP/HTTPS)</b> के माध्यम से सीधे आपके सर्वर पर भेजी जाती हैं।</p>\n<h3>3.3 कोई थर्ड-पार्टी एनालिटिक्स या ट्रैकिंग नहीं</h3>\n<p>BackupFlow में कोई थर्ड-पार्टी एनालिटिक्स SDK, ट्रैकर या विज्ञापन नेटवर्क शामिल नहीं है।</p>"
      ],
      [
        "app-store-info",
        "4. App Store और सिस्टम जानकारी",
        "<p>ऐप से जुड़ी एकमात्र बाहरी जानकारी Apple द्वारा App Store के माध्यम से प्रबंधित मानक जानकारी (खरीद सत्यापन, वैकल्पिक अनाम क्रैश रिपोर्ट और सार्वजनिक App Store समीक्षाएं) है, जो Apple की गोपनीयता नीति के अधीन है।</p>"
      ],
      [
        "permissions",
        "5. अनुमतियाँ और डिवाइस एक्सेस",
        "<ul>\n<li><b>फ़ोटो लाइब्रेरी एक्सेस</b>: केवल आपकी फ़ोटो और वीडियो को पढ़कर आपके सर्वर पर बैकअप लेने (और विकल्प चालू होने पर iCloud से मूल फ़ाइलें डाउनलोड करने) के लिए।</li>\n<li><b>फ़ाइलें और फ़ोल्डर एक्सेस</b>: <b>फ़ोल्डर चुनें</b> पर टैप करने पर केवल आपके द्वारा चुने गए फ़ोल्डर को पढ़ने के लिए।</li>\n<li><b>लोकल नेटवर्क और इंटरनेट</b>: केवल आपके FTP, SFTP या WebDAV सर्वर से कनेक्ट होने के लिए।</li>\n<li><b>बैकग्राउंड ऐप रिफ़्रेश और नोटिफ़िकेशन</b>: केवल शेड्यूल किए गए बैकअप (<code>BGTaskScheduler</code>) चलाने और स्थिति बताने के लिए।</li>\n</ul>"
      ],
      [
        "security",
        "6. डेटा सुरक्षा और अखंडता",
        "<ul>\n<li><b>एन्क्रिप्टेड प्रोटोकॉल</b>: <b>SFTP (SSH)</b> और <b>HTTPS WebDAV</b> के ज़रिए सुरक्षित ट्रांसफ़र।</li>\n<li><b>SFTP होस्ट कुंजी जाँच</b>: पहली बार कनेक्ट होने पर सर्वर की SSH पहचान याद रखता है और बदलने पर चेतावनी देता है।</li>\n<li><b>चेकसम (Checksum)</b>: अपलोड की गई फ़ाइलों की अखंडता जाँचने का विकल्प।</li>\n<li><b>कीचेन सुरक्षा</b>: iOS कीचेन में हार्डवेयर-सुरक्षित पासवर्ड एन्क्रिप्शन।</li>\n</ul>"
      ],
      [
        "third-party",
        "7. तृतीय-पक्ष सेवाएँ",
        "<p>BackupFlow डेटा संग्रह, एनालिटिक्स या विज्ञापन के लिए किसी भी तृतीय-पक्ष सेवा से नहीं जुड़ता और केवल आपके द्वारा सेट किए गए सर्वर से संवाद करता है।</p>"
      ],
      [
        "children",
        "8. बच्चों की गोपनीयता",
        "<p>BackupFlow 13 वर्ष से कम उम्र के बच्चों सहित किसी से भी कोई व्यक्तिगत जानकारी एकत्र नहीं करता है।</p>"
      ],
      [
        "your-rights",
        "9. आपके अधिकार, नियंत्रण और डेटा रीसेट",
        "<p>आपके iPhone पर आपके डेटा का पूरा नियंत्रण आपके पास है:</p>\n<ul>\n<li><b>बैकअप हब</b> से कभी भी अपने टास्क और सर्वर संपादित या डिलीट करें।</li>\n<li><b>बैकअप इतिहास</b> में लॉग साफ़ करें या <b>सेटिंग्स › इतिहास अवधारण (दिन)</b> में समय बदलें।</li>\n<li><b>सेटिंग्स › सभी डेटा रीसेट करें</b> पर टैप करके (या ऐप हटाकर) इस डिवाइस से सभी टास्क, इतिहास और सहेजे गए पासवर्ड तुरंत मिटाएँ। आपके सर्वर की फ़ाइलों को छुआ नहीं जाता।</li>\n</ul>"
      ],
      [
        "changes",
        "10. इस गोपनीयता नीति में बदलाव",
        "<p>इस नीति में कोई भी बदलाव होने पर नई तारीख के साथ इसी पेज पर प्रकाशित किया जाएगा।</p>"
      ],
      [
        "contact",
        "11. संपर्क जानकारी",
        "<p>किसी भी प्रश्न के लिए ऐप में <b>सेटिंग्स › सहायता से संपर्क करें</b> या ईमेल के माध्यम से संपर्क करें:</p>\n<ul>\n<li><b>ईमेल</b>: <a href=\"mailto:tamersavasci@icloud.com\">tamersavasci@icloud.com</a></li>\n<li><b>डेवलपर</b>: Tamer Savaşcı</li>\n</ul>"
      ],
      [
        "compliance",
        "12. कानूनी अनुपालन (GDPR / CCPA)",
        "<p>BackupFlow कोई व्यक्तिगत डेटा एकत्र नहीं करता है, इसलिए यह डिज़ाइन के रूप में ही <b>GDPR</b>, <b>CCPA</b> और अंतरराष्ट्रीय गोपनीयता कानूनों का पूर्ण पालन करता है।</p>"
      ]
    ]
  }
};
