# -*- coding: utf-8 -*-
"""Localized Privacy Policy content (Part 1: en, tr, de, fr, es, ru) for BackupFlow."""

PRIVACY_PART_1 = {
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
            (
                "introduction",
                "1. Introduction",
                """<p>Welcome to BackupFlow. We are committed to protecting your privacy and ensuring the security of your data. This Privacy Policy explains how BackupFlow handles information when you use our iOS application and website.</p>
<p><b>Core Principle:</b> BackupFlow operates on a strict <b>local-first, zero-knowledge architecture</b>. Your photos, videos, documents, and server credentials are never uploaded to our servers or any third-party cloud service. All transfers occur directly between your iPhone and the server you configure (NAS, home server, or personal cloud).</p>""",
            ),
            (
                "not-collected",
                "2. Information We Do NOT Collect",
                """<p>BackupFlow does <b>not</b> collect, transmit, store, or sell any of the following:</p>
<ul>
<li>Your photos, videos, or media metadata</li>
<li>Files or folders selected from the iOS Files app</li>
<li>Your server addresses, hostnames, ports, usernames, or passwords</li>
<li>Your backup tasks, schedules, or backup history logs</li>
<li>Device identifiers, advertising IDs (IDFA), or usage analytics</li>
<li>Your IP address, precise location, or contacts</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. How Your Data Stays Private",
                """<h3>3.1 Local Device Storage &amp; iOS Keychain</h3>
<p>All backup task configurations, schedules, history logs, and app preferences are stored locally on your iPhone. Sensitive credentials (such as FTP, SFTP, and WebDAV passwords) are encrypted inside the <b>iOS Keychain</b> and never leave your device except when authenticating directly with your own server.</p>
<h3>3.2 Direct Device-to-Server Transfer</h3>
<p>When a backup runs, your files are transferred directly from your iPhone to your designated server using standard protocols (<b>FTP</b>, <b>SFTP/SSH</b>, or <b>WebDAV over HTTP/HTTPS</b>). BackupFlow does not route traffic through any intermediate or proxy servers.</p>
<h3>3.3 Zero Third-Party Analytics or Tracking</h3>
<p>BackupFlow contains no third-party analytics SDKs, telemetry trackers, crash-reporting SDKs, or advertising frameworks.</p>""",
            ),
            (
                "app-store-info",
                "4. App Store & System Information",
                """<p>The only external information associated with the app is standard data processed by Apple through the App Store:</p>
<ul>
<li>App purchase and download verification (processed entirely by Apple App Store)</li>
<li>Aggregated, anonymized crash logs or diagnostics (only if you have opted in to share diagnostics with app developers in iOS Settings)</li>
<li>Public ratings and reviews you choose to post on the App Store</li>
</ul>
<p>This information is governed by Apple's Privacy Policy and cannot be used by us to identify you personally.</p>""",
            ),
            (
                "permissions",
                "5. Permissions & Device Access",
                """<ul>
<li><b>Photo Library Access</b>: Used solely to read new or modified photos and videos (and optionally download originals from iCloud Photos when <i>Download iCloud items if needed</i> is enabled) so they can be backed up to your server.</li>
<li><b>Files &amp; Folders Access</b>: When you choose <b>Select Folder</b>, BackupFlow uses iOS security-scoped bookmarks solely to read the folder you selected in the Files app.</li>
<li><b>Local Network &amp; Internet Access</b>: Used exclusively to connect to your configured FTP, SFTP, or WebDAV server on your home Wi-Fi or over the internet.</li>
<li><b>Background App Refresh</b>: Used with iOS <code>BGTaskScheduler</code> to execute your scheduled backups in the background when conditions (Wi-Fi, power, battery, time window) are met.</li>
<li><b>Notifications</b>: Used only to inform you of backup completion, errors, or pending scheduled tasks.</li>
</ul>""",
            ),
            (
                "security",
                "6. Data Security & Integrity",
                """<ul>
<li><b>Encrypted Protocols</b>: Supports encrypted transfers via <b>SFTP (SSH)</b> and <b>WebDAV over HTTPS</b>.</li>
<li><b>SFTP Host Key Verification</b>: Remembers your SFTP server's SSH fingerprint on first connection and alerts you if the server identity ever changes.</li>
<li><b>Checksum Verification</b>: Optional <b>Checksum</b> mode verifies that uploaded files arrive on your server intact.</li>
<li><b>Keychain Protection</b>: Credentials are protected by hardware-backed iOS Keychain encryption.</li>
</ul>""",
            ),
            (
                "third-party",
                "7. Third-Party Services",
                """<p>BackupFlow does not integrate with any third-party cloud, analytics, or advertising services. The app communicates solely with the backup server addresses that you explicitly configure.</p>""",
            ),
            (
                "children",
                "8. Children's Privacy",
                """<p>BackupFlow does not knowingly or unknowingly collect personal data from anyone, including children under the age of 13 (or the applicable age in your jurisdiction).</p>""",
            ),
            (
                "your-rights",
                "9. Your Rights, Control & Data Reset",
                """<p>Because we do not collect or store any of your personal data on external servers, you hold complete control directly on your iPhone:</p>
<ul>
<li>You can view, edit, or delete individual backup tasks and saved servers at any time from the <b>Backup Hub</b>.</li>
<li>You can clear your backup logs at any time in <b>Backup History</b> or adjust automatic expiration in <b>Settings › History Retention (Days)</b>.</li>
<li>You can permanently wipe all tasks, history, and saved Keychain passwords from your device at any time by tapping <b>Settings › Reset All Data</b>, or by uninstalling BackupFlow. Files already backed up on your servers are never affected.</li>
</ul>""",
            ),
            (
                "changes",
                "10. Changes to This Privacy Policy",
                """<p>We may update this Privacy Policy from time to time to reflect new app features or legal requirements. Updates will be posted on this page with a revised "Last updated" date.</p>""",
            ),
            (
                "contact",
                "11. Contact Information",
                """<p>If you have any questions about this Privacy Policy or BackupFlow's privacy practices, you can reach us via <b>Settings › Contact Support</b> in the app or directly at:</p>
<ul>
<li><b>Email</b>: <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>Developer</b>: Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. Jurisdiction & Compliance",
                """<p>BackupFlow is designed to comply with global privacy regulations, including the European Union General Data Protection Regulation (<b>GDPR</b>), the Turkish Personal Data Protection Law (<b>KVKK</b>), the California Consumer Privacy Act (<b>CCPA</b>), and Apple App Store privacy guidelines. Because no personal data is collected or processed by us, your privacy is protected by design.</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. Giriş",
                """<p>BackupFlow'a hoş geldiniz. Gizliliğinizi korumaya ve verilerinizin güvenliğini sağlamaya kararlıyız. Bu Gizlilik Politikası, iOS uygulamamızı ve web sitemizi kullandığınızda verilerinizin nasıl korunduğunu açıklar.</p>
<p><b>Temel İlke:</b> BackupFlow, <b>yerel öncelikli ve sıfır erişimli (zero-knowledge)</b> bir mimariyle çalışır. Fotoğraflarınız, videolarınız, belgeleriniz ve sunucu kimlik bilgileriniz hiçbir zaman bizim sunucularımıza veya üçüncü taraf bir bulut hizmetine yüklenmez. Tüm veri aktarımı doğrudan iPhone'unuz ile sizin belirlediğiniz sunucu (NAS, ev sunucusu veya kişisel bulut) arasında gerçekleşir.</p>""",
            ),
            (
                "not-collected",
                "2. Toplamadığımız Bilgiler",
                """<p>BackupFlow aşağıdaki verilerin hiçbirini <b>toplamaz, saklamaz, işlemez veya paylaşmaz</b>:</p>
<ul>
<li>Fotoğraflarınız, videolarınız veya medya üst verileriniz (EXIF/konum vb.)</li>
<li>iOS Dosyalar uygulamasından seçtiğiniz klasör ve dosyalar</li>
<li>Sunucu adresleriniz, port numaralarınız, kullanıcı adlarınız veya şifreleriniz</li>
<li>Yedekleme görevleriniz, zamanlama ayarlarınız veya yedekleme geçmişiniz</li>
<li>Cihaz kimlikleri, reklam kimlikleri (IDFA) veya kullanım istatistikleri</li>
<li>IP adresiniz, konum verileriniz veya rehberiniz</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. Verileriniz Nasıl Gizli Kalır?",
                """<h3>3.1 Yerel Veri Depolama ve iOS Anahtarlık (Keychain)</h3>
<p>Tüm yedekleme görevleriniz, zamanlama tercihleriniz, geçmiş kayıtlarınız ve uygulama ayarlarınız yalnızca iPhone'unuzda yerel olarak saklanır. Sunucu parolalarınız (FTP, SFTP ve WebDAV şifreleri) donanım destekli <b>iOS Keychain (Anahtarlık)</b> içinde şifrelenir ve kendi sunucunuza bağlanmak dışında cihazınızdan asla çıkmaz.</p>
<h3>3.2 Doğrudan Sunucu İletişimi</h3>
<p>Yedekleme çalıştığında dosyalarınız standart protokoller (<b>FTP</b>, <b>SFTP/SSH</b> veya <b>HTTP/HTTPS üzerinden WebDAV</b>) kullanılarak doğrudan iPhone'unuzdan kendi sunucunuza aktarılır. Arada hiçbir aracı sunucu bulunmaz.</p>
<h3>3.3 Üçüncü Taraf Analiz veya Takip Yok</h3>
<p>BackupFlow içerisinde hiçbir üçüncü taraf analiz aracı, reklam ağı veya kullanıcı takip SDK'sı yer almaz.</p>""",
            ),
            (
                "app-store-info",
                "4. App Store ve Sistem Bilgileri",
                """<p>Uygulamayla ilişkili tek dış veri, Apple tarafından App Store üzerinden standart olarak yönetilen bilgilerdir:</p>
<ul>
<li>Uygulama indirme, ücretsiz deneme kullanımı ve isteğe bağlı uygulama içi satın alma (BackupFlow Pro Lifetime) doğrulama bilgileri (tamamen Apple StoreKit tarafından işlenir)</li>
<li>Anonimleştirilmiş çökme raporları (yalnızca iOS ayarlarında geliştiricilerle paylaşmayı seçtiyseniz)</li>
<li>App Store'da herkese açık olarak yazdığınız puan ve değerlendirmeler</li>
</ul>
<p>Bu bilgiler Apple'ın gizlilik politikasına tabidir ve bireysel kullanıcıları kimliklendirmek için tarafımızca kullanılamaz.</p>""",
            ),
            (
                "permissions",
                "5. İzinler ve Cihaz Erişimi",
                """<ul>
<li><b>Fotoğraf Galerisi Erişimi</b>: Yalnızca fotoğraf ve videolarınızı okuyup sunucunuza yedeklemek (ve <i>Gerekirse iCloud öğelerini indir</i> seçeneği açıksa iCloud'daki orijinalleri indirmek) için kullanılır.</li>
<li><b>Dosyalar ve Klasör Erişimi</b>: <b>Klasör Seç</b> özelliğini kullandığınızda, yalnızca Dosyalar uygulamasında seçtiğiniz klasörü okumak için iOS güvenli yer imleri (security-scoped bookmarks) kullanılır.</li>
<li><b>Yerel Ağ ve İnternet Erişimi</b>: Yalnızca yapılandırdığınız FTP, SFTP veya WebDAV sunucusuna ev Wi-Fi ağınızdan veya internetten bağlanmak için kullanılır.</li>
<li><b>Arka Planda Uygulama Yenileme</b>: Belirlediğiniz koşullar (Wi-Fi, şarj, pil, saat aralığı) sağlandığında zamanlanmış yedeklemeleri iOS <code>BGTaskScheduler</code> ile çalıştırmak için kullanılır.</li>
<li><b>Bildirimler</b>: Yalnızca yedekleme durumu, tamamlanma veya hatalar hakkında sizi bilgilendirmek için kullanılır.</li>
</ul>""",
            ),
            (
                "security",
                "6. Veri Güvenliği ve Bütünlüğü",
                """<ul>
<li><b>Şifreli Protokoller</b>: <b>SFTP (SSH)</b> ve <b>HTTPS üzerinden WebDAV</b> ile uçtan uca şifreli veri aktarımını destekler.</li>
<li><b>SFTP Sunucu Kimliği Doğrulama</b>: İlk bağlantıda SFTP sunucunuzun SSH parmak izini kaydeder ve sunucu kimliği değişirse sizi uyarır.</li>
<li><b>Sağlama Toplamı (Checksum)</b>: İsteğe bağlı <b>Sağlama toplamı</b> özelliği ile yüklenen dosyaların sunucuya eksiksiz ulaştığını doğrular.</li>
<li><b>Anahtarlık Koruması</b>: Parolalar iOS Keychain şifrelemesiyle korunur.</li>
</ul>""",
            ),
            (
                "third-party",
                "7. Üçüncü Taraf Hizmetler",
                """<p>BackupFlow veri toplama, analiz veya reklam amacıyla hiçbir üçüncü taraf hizmetle entegre değildir. Uygulama yalnızca sizin açıkça tanımladığınız yedekleme sunucularıyla iletişim kurar.</p>""",
            ),
            (
                "children",
                "8. Çocukların Gizliliği",
                """<p>BackupFlow, 13 yaş altı çocuklar dahil olmak üzere hiç kimseden kişisel veri toplamaz ve her yaştan kullanıcı için güvenlidir.</p>""",
            ),
            (
                "your-rights",
                "9. Haklarınız, Kontrol ve Verileri Sıfırlama",
                """<p>Kişisel verilerinizi toplamadığımız için tüm verilerinizin kontrolü doğrudan kendi cihazınızdadır:</p>
<ul>
<li><b>Yedekleme Merkezi</b> üzerinden görevlerinizi ve kayıtlı sunucularınızı istediğiniz an düzenleyebilir veya silebilirsiniz.</li>
<li><b>Yedek Geçmişi</b> ekranından geçmiş kayıtlarını temizleyebilir veya <b>Ayarlar › Geçmiş Saklama (Gün)</b> ile saklama süresini belirleyebilirsiniz.</li>
<li><b>Ayarlar › Tüm Verileri Sıfırla</b> seçeneğine dokunarak (veya uygulamayı silerek) tüm görevleri, geçmişi ve kayıtlı parolaları cihazınızdan anında silebilirsiniz. Sunucularınızdaki yedeklenmiş dosyalara dokunulmaz.</li>
</ul>""",
            ),
            (
                "changes",
                "10. Gizlilik Politikasındaki Değişiklikler",
                """<p>Bu Gizlilik Politikasını yeni özellikler veya yasal gereklilikler doğrultusunda zaman zaman güncelleyebiliriz. Yapılan değişiklikler güncellenmiş tarih ile bu sayfada yayınlanır.</p>""",
            ),
            (
                "contact",
                "11. İletişim Bilgileri",
                """<p>Bu Gizlilik Politikası hakkında sorularınız için uygulama içindeki <b>Ayarlar › Destek İletişim</b> bölümünden veya doğrudan aşağıdaki bilgilerden bize ulaşabilirsiniz:</p>
<ul>
<li><b>E-posta</b>: <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>Geliştirici</b>: Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. Yasal Uyumluluk",
                """<p>BackupFlow; Kişisel Verilerin Korunması Kanunu (<b>KVKK</b>), Avrupa Birliği Genel Veri Koruma Tüzüğü (<b>GDPR</b>), Kaliforniya Tüketici Gizliliği Yasası (<b>CCPA</b>) ve Apple App Store gizlilik standartlarına tam uyumlu olacak şekilde tasarlanmıştır. Hiçbir kişisel veri toplanmadığı için gizliliğiniz tasarım gereği (privacy by design) korunmaktadır.</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. Einleitung",
                """<p>Willkommen bei BackupFlow. Der Schutz Ihrer Privatsphäre und die Sicherheit Ihrer Daten haben für uns höchste Priorität. Diese Datenschutzrichtlinie erläutert, wie BackupFlow mit Daten umgeht, wenn Sie unsere iOS-App und Website nutzen.</p>
<p><b>Grundprinzip:</b> BackupFlow arbeitet vollständig lokal. Ihre Fotos, Videos, Dokumente und Server-Zugangsdaten werden niemals auf unsere Server oder an Drittanbieter-Clouds übertragen. Alle Übertragungen finden direkt zwischen Ihrem iPhone und Ihrem eigenen Server (NAS, Heimserver oder persönliche Cloud) statt.</p>""",
            ),
            (
                "not-collected",
                "2. Daten, die wir NICHT erheben",
                """<p>BackupFlow erhebt, speichert oder überträgt <b>keine</b> der folgenden Informationen:</p>
<ul>
<li>Ihre Fotos, Videos oder Medien-Metadaten</li>
<li>Dateien oder Ordner aus der iOS-Dateien-App</li>
<li>Serveradressen, Ports, Benutzernamen oder Passwörter</li>
<li>Backup-Aufgaben, Zeitpläne oder Backup-Verläufe</li>
<li>Geräte-IDs, Werbe-IDs (IDFA) oder Nutzungsstatistiken</li>
<li>Ihre IP-Adresse, Standortdaten oder Kontakte</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. Wie Ihre Daten privat bleiben",
                """<h3>3.1 Lokale Speicherung &amp; iOS-Schlüsselbund (Keychain)</h3>
<p>Alle Aufgaben, Zeitpläne, Verläufe und Einstellungen werden ausschließlich lokal auf Ihrem iPhone gespeichert. Zugangsdaten (FTP-, SFTP- und WebDAV-Passwörter) werden verschlüsselt im <b>iOS-Schlüsselbund (Keychain)</b> abgelegt und verlassen Ihr Gerät nur zur direkten Anmeldung an Ihrem eigenen Server.</p>
<h3>3.2 Direkte Server-Kommunikation</h3>
<p>Beim Backup werden Ihre Dateien direkt per <b>FTP</b>, <b>SFTP (SSH)</b> oder <b>WebDAV (HTTP/HTTPS)</b> an Ihren Server gesendet – ohne Zwischenserver.</p>
<h3>3.3 Keine Analyse- oder Tracking-Dienste</h3>
<p>BackupFlow enthält keinerlei Analyse-SDKs, Werbenetzwerke oder Tracking-Tools von Drittanbietern.</p>""",
            ),
            (
                "app-store-info",
                "4. App Store- und Systeminformationen",
                """<p>Die einzigen externen Informationen sind Standarddaten, die Apple über den App Store abwickelt (Kaufabwicklung, optionale anonymisierte Absturzberichte über iOS-Einstellungen sowie öffentliche App-Store-Rezensionen). Diese Daten unterliegen der Datenschutzrichtlinie von Apple.</p>""",
            ),
            (
                "permissions",
                "5. Berechtigungen & Gerätezugriff",
                """<ul>
<li><b>Fotomediathek</b>: Nur zum Lesen und Sichern Ihrer Fotos und Videos auf Ihrem Server (inkl. optionalem Laden von iCloud-Originalen).</li>
<li><b>Dateien &amp; Ordner</b>: Beim Tippen auf <b>Ordner auswählen</b> greift BackupFlow nur über geschützte iOS-Lesezeichen auf den von Ihnen gewählten Ordner zu.</li>
<li><b>Lokales Netzwerk &amp; Internet</b>: Ausschließlich für die Verbindung zu Ihrem FTP-, SFTP- oder WebDAV-Server.</li>
<li><b>Hintergrundaktualisierung &amp; Mitteilungen</b>: Nur zur Ausführung geplanter Backups über den <code>BGTaskScheduler</code> und für Statusbenachrichtigungen.</li>
</ul>""",
            ),
            (
                "security",
                "6. Datensicherheit & Integrität",
                """<ul>
<li><b>Verschlüsselung</b>: Unterstützt verschlüsselte Übertragungen per <b>SFTP (SSH)</b> und <b>HTTPS-WebDAV</b>.</li>
<li><b>SFTP-Serverprüfung</b>: Speichert den SSH-Fingerabdruck Ihres Servers bei der ersten Verbindung und warnt bei Änderungen.</li>
<li><b>Prüfsumme (Checksum)</b>: Optionale Integritätsprüfung nach dem Upload.</li>
<li><b>Schlüsselbund-Schutz</b>: Hardwaregestützte Verschlüsselung Ihrer Passwörter im iOS Keychain.</li>
</ul>""",
            ),
            (
                "third-party",
                "7. Dienste von Drittanbietern",
                """<p>BackupFlow integriert keine Drittanbieter-Dienste für Datenerhebung, Analyse oder Werbung und kommuniziert ausschließlich mit den von Ihnen konfigurierten Servern.</p>""",
            ),
            (
                "children",
                "8. Datenschutz für Kinder",
                """<p>BackupFlow sammelt von niemandem personenbezogene Daten, auch nicht von Kindern unter 13 Jahren.</p>""",
            ),
            (
                "your-rights",
                "9. Ihre Rechte, Kontrolle & Daten zurücksetzen",
                """<p>Sie behalten jederzeit die volle Kontrolle über alle lokalen Daten auf Ihrem iPhone:</p>
<ul>
<li>Aufgaben und Server lassen sich jederzeit in der <b>Backup-Zentrale</b> bearbeiten oder löschen.</li>
<li>Den Verlauf können Sie im <b>Backup-Verlauf</b> leeren oder über <b>Einstellungen › Verlaufsaufbewahrung (Tage)</b> begrenzen.</li>
<li>Über <b>Einstellungen › Alle Daten zurücksetzen</b> (oder durch Deinstallieren der App) löschen Sie sofort alle Aufgaben, Verläufe und gespeicherten Passwörter von Ihrem Gerät. Dateien auf Ihren Servern bleiben unberührt.</li>
</ul>""",
            ),
            (
                "changes",
                "10. Änderungen dieser Datenschutzrichtlinie",
                """<p>Aktualisierungen dieser Richtlinie werden auf dieser Seite mit einem aktualisierten Datum veröffentlicht.</p>""",
            ),
            (
                "contact",
                "11. Kontakt",
                """<p>Bei Fragen erreichen Sie uns über <b>Einstellungen › Support kontaktieren</b> in der App oder per E-Mail:</p>
<ul>
<li><b>E-Mail</b>: <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>Entwickler</b>: Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. Rechtskonformität (DSGVO / GDPR)",
                """<p>BackupFlow erfüllt die Anforderungen der Europäischen Datenschutz-Grundverordnung (<b>DSGVO / GDPR</b>), des <b>CCPA</b> sowie weiterer internationaler Datenschutzgesetze durch konsequenten Datenschutz durch Technikgestaltung (Privacy by Design).</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. Introduction",
                """<p>Bienvenue sur BackupFlow. Nous nous engageons à protéger votre vie privée. Cette Politique de confidentialité explique comment BackupFlow traite les informations lorsque vous utilisez notre application iOS et notre site web.</p>
<p><b>Principe fondamental :</b> BackupFlow fonctionne entièrement en local. Vos photos, vidéos, documents et identifiants ne sont jamais envoyés sur nos serveurs ni sur un service cloud tiers. Tous les transferts s'effectuent directement entre votre iPhone et votre propre serveur (NAS, serveur domestique ou cloud personnel).</p>""",
            ),
            (
                "not-collected",
                "2. Informations que nous NE collectons PAS",
                """<p>BackupFlow ne collecte, ne stocke et ne partage <b>aucune</b> des données suivantes :</p>
<ul>
<li>Vos photos, vidéos ou métadonnées multimédias</li>
<li>Les fichiers ou dossiers sélectionnés depuis l'app Fichiers</li>
<li>Les adresses de vos serveurs, ports, noms d'utilisateur ou mots de passe</li>
<li>Vos tâches de sauvegarde, votre planification ou votre historique</li>
<li>Les identifiants d'appareil, identifiants publicitaires (IDFA) ou données d'analyse</li>
<li>Votre adresse IP, votre localisation ou vos contacts</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. Comment vos données restent privées",
                """<h3>3.1 Stockage local et Trousseau iOS (Keychain)</h3>
<p>Toutes les configurations de tâches, planifications, journaux d'historique et préférences sont stockés localement sur votre iPhone. Vos mots de passe (FTP, SFTP et WebDAV) sont chiffrés dans le <b>Trousseau iOS (Keychain)</b> et ne quittent jamais votre appareil sauf pour s'authentifier auprès de votre serveur.</p>
<h3>3.2 Transfert direct vers votre serveur</h3>
<p>Lors d'une sauvegarde, vos fichiers sont transférés directement de votre iPhone vers votre serveur via <b>FTP</b>, <b>SFTP (SSH)</b> ou <b>WebDAV (HTTP/HTTPS)</b>, sans aucun serveur intermédiaire.</p>
<h3>3.3 Aucune analyse ni pistage tiers</h3>
<p>BackupFlow n'intègre aucun SDK d'analyse, de télémétrie ou de publicité.</p>""",
            ),
            (
                "app-store-info",
                "4. Informations App Store et système",
                """<p>Les seules données externes sont celles gérées directement par Apple via l'App Store (validation d'achat, rapports de plantage anonymisés optionnels d'iOS et avis publics sur l'App Store), soumises à la politique de confidentialité d'Apple.</p>""",
            ),
            (
                "permissions",
                "5. Autorisations et accès à l'appareil",
                """<ul>
<li><b>Photothèque</b> : Utilisée uniquement pour lire et sauvegarder vos photos et vidéos vers votre serveur (y compris le téléchargement optionnel des originaux iCloud).</li>
<li><b>Fichiers et dossiers</b> : Lorsque vous touchez <b>Sélectionner un dossier</b>, BackupFlow accède uniquement au dossier choisi dans l'app Fichiers.</li>
<li><b>Réseau local et Internet</b> : Utilisé exclusivement pour se connecter à votre serveur FTP, SFTP ou WebDAV.</li>
<li><b>Actualisation en arrière-plan et Notifications</b> : Utilisées uniquement pour exécuter les sauvegardes planifiées (<code>BGTaskScheduler</code>) et vous informer de leur état.</li>
</ul>""",
            ),
            (
                "security",
                "6. Sécurité et intégrité des données",
                """<ul>
<li><b>Protocoles chiffrés</b> : Prise en charge de <b>SFTP (SSH)</b> et <b>WebDAV via HTTPS</b>.</li>
<li><b>Vérification de clé d'hôte SFTP</b> : Mémorise l'empreinte SSH de votre serveur lors de la première connexion et vous avertit en cas de modification.</li>
<li><b>Somme de contrôle (Checksum)</b> : Vérification optionnelle de l'intégrité des fichiers envoyés.</li>
<li><b>Protection Keychain</b> : Chiffrement matériel des mots de passe dans le Trousseau iOS.</li>
</ul>""",
            ),
            (
                "third-party",
                "7. Services tiers",
                """<p>BackupFlow n'utilise aucun service tiers de collecte de données ou de publicité et communique uniquement avec les serveurs que vous configurez.</p>""",
            ),
            (
                "children",
                "8. Confidentialité des enfants",
                """<p>BackupFlow ne collecte aucune donnée personnelle auprès de qui que ce soit, y compris des enfants de moins de 13 ans.</p>""",
            ),
            (
                "your-rights",
                "9. Vos droits, contrôle et réinitialisation",
                """<p>Vous gardez le contrôle total sur votre appareil :</p>
<ul>
<li>Modifiez ou supprimez vos tâches à tout moment depuis le <b>Centre de sauvegarde</b>.</li>
<li>Effacez l'historique dans <b>Historique des sauvegardes</b> ou ajustez la durée dans <b>Paramètres › Rétention de l'historique (jours)</b>.</li>
<li>Touchez <b>Paramètres › Réinitialiser toutes les données</b> (ou désinstallez l'application) pour supprimer immédiatement toutes les tâches, l'historique et les mots de passe enregistrés sur cet iPhone. Vos fichiers sur vos serveurs ne sont jamais touchés.</li>
</ul>""",
            ),
            (
                "changes",
                "10. Modifications de cette politique",
                """<p>Toute mise à jour de cette Politique de confidentialité sera publiée sur cette page avec une date actualisée.</p>""",
            ),
            (
                "contact",
                "11. Contact",
                """<p>Pour toute question, contactez-nous via <b>Paramètres › Contacter le support</b> dans l'application ou par e-mail :</p>
<ul>
<li><b>E-mail</b> : <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>Développeur</b> : Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. Juridiction et conformité (RGPD / GDPR)",
                """<p>BackupFlow respecte le Règlement général sur la protection des données (<b>RGPD / GDPR</b>), le <b>CCPA</b> et les réglementations internationales en matière de vie privée grâce à une protection dès la conception (Privacy by Design).</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. Introducción",
                """<p>Bienvenido a BackupFlow. Nos comprometemos a proteger tu privacidad y la seguridad de tu información. Esta Política de privacidad explica cómo funciona BackupFlow cuando utilizas nuestra aplicación para iOS y nuestro sitio web.</p>
<p><b>Principio clave:</b> BackupFlow funciona con una arquitectura estrictamente local. Tus fotos, vídeos, documentos y credenciales nunca se suben a nuestros servidores ni a servicios en la nube de terceros. Todas las transferencias se realizan directamente entre tu iPhone y el servidor que configures (NAS, servidor doméstico o nube personal).</p>""",
            ),
            (
                "not-collected",
                "2. Información que NO recopilamos",
                """<p>BackupFlow <b>no</b> recopila, almacena ni comparte ninguno de los siguientes datos:</p>
<ul>
<li>Tus fotos, vídeos o metadatos multimedia</li>
<li>Archivos o carpetas seleccionados desde la app Archivos de iOS</li>
<li>Direcciones de tus servidores, puertos, nombres de usuario o contraseñas</li>
<li>Tus tareas de copia de seguridad, horarios o historial de copias</li>
<li>Identificadores del dispositivo, ID de publicidad (IDFA) o analíticas de uso</li>
<li>Tu dirección IP, ubicación o contactos</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. Cómo se mantienen privados tus datos",
                """<h3>3.1 Almacenamiento local y Llavero de iOS (Keychain)</h3>
<p>Todas las tareas, horarios, registros de historial y ajustes se guardan localmente en tu iPhone. Las contraseñas de tus servidores (FTP, SFTP y WebDAV) se cifran en el <b>Llavero de iOS (Keychain)</b> y nunca salen de tu dispositivo salvo para autenticarse directamente con tu propio servidor.</p>
<h3>3.2 Transferencia directa al servidor</h3>
<p>Al realizar una copia, tus archivos viajan directamente desde tu iPhone a tu servidor mediante <b>FTP</b>, <b>SFTP (SSH)</b> o <b>WebDAV (HTTP/HTTPS)</b>, sin servidores intermediarios.</p>
<h3>3.3 Sin analíticas ni rastreadores de terceros</h3>
<p>BackupFlow no incluye SDKs de analítica, seguimiento ni publicidad de terceros.</p>""",
            ),
            (
                "app-store-info",
                "4. Información del App Store y del sistema",
                """<p>La única información externa es la gestionada por Apple en el App Store (validación de compra, informes de fallos anónimos opcionales de iOS y reseñas públicas en el App Store), sujeta a la política de privacidad de Apple.</p>""",
            ),
            (
                "permissions",
                "5. Permisos y acceso al dispositivo",
                """<ul>
<li><b>Biblioteca de fotos</b>: Se usa únicamente para leer y copiar tus fotos y vídeos en tu servidor (incluida la descarga opcional de originales de iCloud).</li>
<li><b>Archivos y carpetas</b>: Al elegir <b>Seleccionar carpeta</b>, BackupFlow accede únicamente a la carpeta elegida en la app Archivos.</li>
<li><b>Red local e Internet</b>: Se usa exclusivamente para conectar con tu servidor FTP, SFTP o WebDAV.</li>
<li><b>Actualización en segundo plano y Notificaciones</b>: Se usan solo para ejecutar copias programadas (<code>BGTaskScheduler</code>) y avisarte de su estado.</li>
</ul>""",
            ),
            (
                "security",
                "6. Seguridad e integridad de los datos",
                """<ul>
<li><b>Protocolos cifrados</b>: Compatible con transferencias cifradas mediante <b>SFTP (SSH)</b> y <b>WebDAV sobre HTTPS</b>.</li>
<li><b>Verificación de clave SFTP</b>: Recuerda la huella SSH de tu servidor en la primera conexión y te avisa si cambia.</li>
<li><b>Suma de verificación (Checksum)</b>: Comprobación opcional de integridad tras la subida.</li>
<li><b>Protección en el Llavero</b>: Contraseñas protegidas mediante el cifrado del Llavero de iOS.</li>
</ul>""",
            ),
            (
                "third-party",
                "7. Servicios de terceros",
                """<p>BackupFlow no se integra con ningún servicio de terceros para recopilación de datos, analíticas o publicidad, y solo se comunica con los servidores que tú configuras.</p>""",
            ),
            (
                "children",
                "8. Privacidad infantil",
                """<p>BackupFlow no recopila información personal de nadie, incluidos menores de 13 años.</p>""",
            ),
            (
                "your-rights",
                "9. Tus derechos, control y restablecimiento de datos",
                """<p>Mantienes el control total en tu iPhone:</p>
<ul>
<li>Puedes editar o eliminar tareas y servidores en cualquier momento desde el <b>Centro de copias</b>.</li>
<li>Puedes borrar el historial en <b>Historial de copias</b> o ajustar su duración en <b>Ajustes › Retención de historial (días)</b>.</li>
<li>Puedes eliminar todas las tareas, el historial y las contraseñas guardadas de tu dispositivo tocando <b>Ajustes › Restablecer todos los datos</b> o desinstalando la app. Los archivos en tus servidores no se ven afectados.</li>
</ul>""",
            ),
            (
                "changes",
                "10. Cambios en esta Política de privacidad",
                """<p>Cualquier cambio en esta política se publicará en esta página con una fecha de actualización revisada.</p>""",
            ),
            (
                "contact",
                "11. Información de contacto",
                """<p>Si tienes preguntas, contáctanos desde <b>Ajustes › Contactar soporte</b> en la app o por correo electrónico:</p>
<ul>
<li><b>Correo electrónico</b>: <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>Desarrollador</b>: Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. Jurisdicción y cumplimiento (RGPD / CCPA)",
                """<p>BackupFlow cumple con el Reglamento General de Protección de Datos (<b>RGPD / GDPR</b>), la <b>CCPA</b> y demás normativas internacionales de privacidad mediante privacidad por diseño.</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. Введение",
                """<p>Добро пожаловать в BackupFlow. Мы уделяем первостепенное внимание защите вашей конфиденциальности. Настоящая Политика конфиденциальности объясняет, как BackupFlow обрабатывает данные при использовании нашего iOS-приложения и веб-сайта.</p>
<p><b>Ключевой принцип:</b> BackupFlow работает полностью локально. Ваши фотографии, видео, документы и учётные данные серверов никогда не загружаются на наши серверы или в сторонние облачные сервисы. Все файлы передаются напрямую между вашим iPhone и выбранным вами сервером (NAS, домашним сервером или личным облаком).</p>""",
            ),
            (
                "not-collected",
                "2. Данные, которые мы НЕ собираем",
                """<p>BackupFlow <b>не</b> собирает, не хранит и не передаёт третьим лицам следующую информацию:</p>
<ul>
<li>Ваши фотографии, видеозаписи и метаданные медиафайлов</li>
<li>Файлы и папки, выбранные в приложении «Файлы» на iOS</li>
<li>Адреса серверов, порты, имена пользователей и пароли</li>
<li>Ваши задачи резервного копирования, расписание и журнал истории</li>
<li>Идентификаторы устройств, рекламные идентификаторы (IDFA) и аналитику использования</li>
<li>Ваш IP-адрес, геолокацию и контакты</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. Как обеспечивается конфиденциальность",
                """<h3>3.1 Локальное хранение и Связка ключей iOS (Keychain)</h3>
<p>Все настройки задач, расписания, история и параметры приложения хранятся локально на вашем iPhone. Пароли от серверов (FTP, SFTP и WebDAV) зашифрованы в <b>Связке ключей iOS (Keychain)</b> и никогда не покидают устройство, кроме как для прямой авторизации на вашем сервере.</p>
<h3>3.2 Прямая передача на сервер</h3>
<p>Во время резервного копирования файлы передаются напрямую с iPhone на ваш сервер по протоколам <b>FTP</b>, <b>SFTP (SSH)</b> или <b>WebDAV (HTTP/HTTPS)</b> без промежуточных серверов.</p>
<h3>3.3 Никакой сторонней аналитики и слежки</h3>
<p>В BackupFlow нет сторонних аналитических SDK, рекламных сетей или трекеров.</p>""",
            ),
            (
                "app-store-info",
                "4. Информация App Store и системы",
                """<p>Единственные внешние данные — это стандартная информация, обрабатываемая корпорацией Apple через App Store (подтверждение покупки, опциональные анонимные отчёты о сбоях iOS и публичные отзывы в App Store), которая регулируется политикой конфиденциальности Apple.</p>""",
            ),
            (
                "permissions",
                "5. Разрешения и доступ к устройству",
                """<ul>
<li><b>Доступ к Фото</b>: Используется исключительно для чтения и копирования ваших фото и видео на ваш сервер (включая опциональную загрузку оригиналов из Фото iCloud).</li>
<li><b>Доступ к Файлам и папкам</b>: При выборе <b>Выбрать папку</b> приложение обращается только к указанной вами папке в приложении «Файлы».</li>
<li><b>Локальная сеть и Интернет</b>: Используются только для подключения к вашему серверу FTP, SFTP или WebDAV.</li>
<li><b>Фоновое обновление и Уведомления</b>: Используются только для запуска копий по расписанию (<code>BGTaskScheduler</code>) и уведомлений о статусе.</li>
</ul>""",
            ),
            (
                "security",
                "6. Безопасность и целостность данных",
                """<ul>
<li><b>Шифрование передачи</b>: Поддержка защищённых протоколов <b>SFTP (SSH)</b> и <b>WebDAV по HTTPS</b>.</li>
<li><b>Проверка ключа сервера SFTP</b>: Запоминает SSH-отпечаток вашего сервера при первом подключении и предупреждает при его изменении.</li>
<li><b>Контрольная сумма (Checksum)</b>: Опциональная проверка целостности загруженных файлов.</li>
<li><b>Защита в Связке ключей</b>: Аппаратное шифрование паролей в iOS Keychain.</li>
</ul>""",
            ),
            (
                "third-party",
                "7. Сторонние сервисы",
                """<p>BackupFlow не интегрируется со сторонними сервисами аналитики или рекламы и обменивается данными только с настроенными вами серверами.</p>""",
            ),
            (
                "children",
                "8. Конфиденциальность детей",
                """<p>BackupFlow не собирает персональные данные ни у кого, включая детей младше 13 лет.</p>""",
            ),
            (
                "your-rights",
                "9. Ваши права, контроль и сброс данных",
                """<p>Вы полностью контролируете свои данные на iPhone:</p>
<ul>
<li>Редактируйте или удаляйте задачи и серверы в любое время в <b>Центре копий</b>.</li>
<li>Очищайте журнал в разделе <b>История копий</b> или настраивайте срок хранения в <b>Настройки › Хранение истории (дни)</b>.</li>
<li>Нажмите <b>Настройки › Сбросить все данные</b> (или удалите приложение), чтобы мгновенно удалить все задачи, историю и сохранённые пароли с этого устройства. Файлы на ваших серверах не затрагиваются.</li>
</ul>""",
            ),
            (
                "changes",
                "10. Изменения в Политике конфиденциальности",
                """<p>Любые обновления настоящей Политики будут опубликованы на этой странице с новой датой обновления.</p>""",
            ),
            (
                "contact",
                "11. Контактная информация",
                """<p>По всем вопросам вы можете связаться с нами через <b>Настройки › Связаться с поддержкой</b> в приложении или по электронной почте:</p>
<ul>
<li><b>Email</b>: <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>Разработчик</b>: Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. Соответствие законодательству (GDPR / CCPA)",
                """<p>BackupFlow полностью соответствует требованиям <b>GDPR</b>, <b>CCPA</b> и других международных норм о защите данных, поскольку не осуществляет сбор персональных данных.</p>""",
            ),
        ],
    },
}
