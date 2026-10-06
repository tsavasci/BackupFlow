import AppKit

// Custom product pages: ordered screenshots, a page-specific banner and promotional text per language.
let pagesDir = "\(repo)/custom-pages"

struct PageText { let headline: String; let subtitle: String; let promo: String }

struct Page {
    let slug: String
    let name: String           // reference name in App Store Connect
    let bannerShots: [Int]     // left, center (front), right
    let screenshotOrder: [Int] // upload order
    let texts: [String: PageText]
}

let pages: [Page] = [
    Page(slug: "1-fotograf-yedekleme", name: "Fotoğraf Yedekleme",
         bannerShots: [1, 6, 4], screenshotOrder: [6, 1, 4, 3, 2, 9], texts: [
        "Türkçe": PageText(headline: "Fotoğraflarınız güvende.",
            subtitle: "Galerinizi kendi FTP, SFTP veya WebDAV sunucunuza otomatik yedekleyin.",
            promo: "iPhone fotoğraf ve videolarınızı bulut aboneliği olmadan kendi sunucunuza yedekleyin. Yalnızca yeni çekimler aktarılır, depolama tamamen sizin kontrolünüzde."),
        "İngilizce": PageText(headline: "Your photos, safely backed up.",
            subtitle: "Automatically back up your library to your own FTP, SFTP or WebDAV server.",
            promo: "Back up iPhone photos and videos to your own server, no cloud subscription needed. Only new shots are transferred, and your storage stays under your control."),
        "Almanca": PageText(headline: "Deine Fotos. Sicher gesichert.",
            subtitle: "Sichere deine Mediathek automatisch auf deinem eigenen FTP-, SFTP- oder WebDAV-Server.",
            promo: "Sichere iPhone-Fotos und -Videos auf deinem eigenen Server – ganz ohne Cloud-Abo. Nur neue Aufnahmen werden übertragen, dein Speicher bleibt in deiner Hand."),
        "İspanyolca": PageText(headline: "Tus fotos, a salvo.",
            subtitle: "Copia automática de tu fototeca en tu propio servidor FTP, SFTP o WebDAV.",
            promo: "Copia las fotos y vídeos del iPhone en tu propio servidor, sin suscripciones a la nube. Solo se transfieren las fotos nuevas y tú controlas el almacenamiento."),
        "Fransızca": PageText(headline: "Vos photos, en sécurité.",
            subtitle: "Sauvegardez automatiquement votre photothèque sur votre propre serveur FTP, SFTP ou WebDAV.",
            promo: "Sauvegardez photos et vidéos de l'iPhone sur votre serveur, sans abonnement cloud. Seules les nouvelles prises sont envoyées ; vous gardez le contrôle du stockage."),
        "Portekizce": PageText(headline: "Suas fotos, em segurança.",
            subtitle: "Backup automático da sua fototeca no seu próprio servidor FTP, SFTP ou WebDAV.",
            promo: "Faça backup das fotos e vídeos do iPhone no seu próprio servidor, sem assinatura de nuvem. Só as fotos novas são enviadas e o armazenamento fica sob seu controle."),
        "Rusça": PageText(headline: "Ваши фото в безопасности.",
            subtitle: "Автоматическое резервное копирование медиатеки на ваш FTP-, SFTP- или WebDAV-сервер.",
            promo: "Сохраняйте фото и видео с iPhone на своём сервере — без подписки на облако. Передаются только новые снимки, а хранилище полностью под вашим контролем."),
        "Arapça": PageText(headline: "صورك في أمان.",
            subtitle: "نسخ احتياطي تلقائي لمكتبة صورك إلى خادم FTP أو SFTP أو WebDAV الخاص بك.",
            promo: "انسخ صور ومقاطع فيديو iPhone احتياطيًا إلى خادمك الخاص دون اشتراك سحابي. تُنقل الصور الجديدة فقط، وتبقى مساحة التخزين تحت سيطرتك."),
        "Hintçe": PageText(headline: "आपकी फ़ोटो,\nपूरी तरह सुरक्षित।",
            subtitle: "अपनी फ़ोटो लाइब्रेरी का अपने FTP, SFTP या WebDAV सर्वर पर अपने-आप बैकअप लें।",
            promo: "बिना क्लाउड सब्सक्रिप्शन के iPhone की फ़ोटो और वीडियो का अपने सर्वर पर बैकअप लें। सिर्फ़ नई फ़ोटो भेजी जाती हैं, और स्टोरेज आपके नियंत्रण में रहता है।"),
        "Japonca": PageText(headline: "大切な写真を、\nしっかりバックアップ。",
            subtitle: "写真ライブラリを自分の\nFTP・SFTP・WebDAV サーバーへ自動バックアップ。",
            promo: "クラウドの契約なしで、iPhoneの写真やビデオを自分のサーバーにバックアップ。転送されるのは新しい写真だけ。保存先は自分で管理できます。"),
        "Korece": PageText(headline: "소중한 사진을,\n안전하게.",
            subtitle: "사진 보관함을 내 FTP, SFTP, WebDAV 서버로\n자동 백업하세요.",
            promo: "클라우드 구독 없이 iPhone 사진과 동영상을 내 서버에 백업하세요. 새로 찍은 사진만 전송되며, 저장 공간은 직접 관리할 수 있습니다."),
        "Çince": PageText(headline: "你的照片，\n安全备份。",
            subtitle: "将照片图库自动备份到\n你自己的 FTP、SFTP 或 WebDAV 服务器。",
            promo: "无需订阅云服务，即可将 iPhone 照片和视频备份到你自己的服务器。只传输新拍摄的内容，存储空间完全由你掌控。"),
    ]),
    Page(slug: "2-nas-sftp", name: "NAS & SFTP",
         bannerShots: [5, 7, 1], screenshotOrder: [7, 1, 5, 4, 3, 9], texts: [
        "Türkçe": PageText(headline: "iPhone'unuzu NAS'ınıza yedekleyin.",
            subtitle: "NAS'ınıza veya ev sunucunuza güvenli SFTP yedeklemesi.",
            promo: "Fotoğraf ve dosyalarınızı şifreli SFTP bağlantısıyla doğrudan NAS'ınıza ya da ev sunucunuza yedekleyin. Zamanlamayı ayarlayın, gerisini BackupFlow halletsin."),
        "İngilizce": PageText(headline: "Back up your iPhone to your NAS.",
            subtitle: "Secure SFTP backups to your NAS or home server.",
            promo: "Back up photos and files straight to your NAS or home server over an encrypted SFTP connection. Set a schedule and let BackupFlow handle the rest."),
        "Almanca": PageText(headline: "Dein iPhone. Gesichert auf deinem NAS.",
            subtitle: "Sichere SFTP-Backups auf dein NAS oder deinen Heimserver.",
            promo: "Sichere Fotos und Dateien über eine verschlüsselte SFTP-Verbindung direkt auf dein NAS oder deinen Heimserver. Zeitplan festlegen – BackupFlow erledigt den Rest."),
        "İspanyolca": PageText(headline: "Copia tu iPhone en tu NAS.",
            subtitle: "Copias seguras por SFTP en tu NAS o servidor doméstico.",
            promo: "Copia fotos y archivos directamente en tu NAS o servidor doméstico mediante una conexión SFTP cifrada. Programa la copia y BackupFlow se encarga del resto."),
        "Fransızca": PageText(headline: "Sauvegardez votre iPhone sur votre NAS.",
            subtitle: "Sauvegardes SFTP sécurisées vers votre NAS ou serveur domestique.",
            promo: "Sauvegardez photos et fichiers directement sur votre NAS ou serveur domestique via une connexion SFTP chiffrée. Planifiez, BackupFlow s'occupe du reste."),
        "Portekizce": PageText(headline: "Backup do seu iPhone no seu NAS.",
            subtitle: "Backups seguros via SFTP no seu NAS ou servidor doméstico.",
            promo: "Faça backup de fotos e arquivos direto no seu NAS ou servidor doméstico por uma conexão SFTP criptografada. Defina um horário e o BackupFlow cuida do resto."),
        "Rusça": PageText(headline: "Копии iPhone — прямо на ваш NAS.",
            subtitle: "Защищённое резервное копирование по SFTP на NAS или домашний сервер.",
            promo: "Сохраняйте фото и файлы прямо на NAS или домашний сервер через зашифрованное SFTP-соединение. Задайте расписание — остальное сделает BackupFlow."),
        "Arapça": PageText(headline: "انسخ iPhone احتياطيًا إلى NAS الخاص بك.",
            subtitle: "نسخ احتياطي آمن عبر SFTP إلى NAS أو خادمك المنزلي.",
            promo: "انسخ الصور والملفات احتياطيًا مباشرة إلى NAS أو خادمك المنزلي عبر اتصال SFTP مشفّر. حدّد موعدًا ودع BackupFlow يتولى الباقي."),
        "Hintçe": PageText(headline: "अपने iPhone का\nNAS पर बैकअप लें।",
            subtitle: "अपने NAS या होम सर्वर पर सुरक्षित SFTP बैकअप।",
            promo: "एन्क्रिप्टेड SFTP कनेक्शन से फ़ोटो और फ़ाइलों का सीधे अपने NAS या होम सर्वर पर बैकअप लें। शेड्यूल सेट करें, बाकी काम BackupFlow करेगा।"),
        "Japonca": PageText(headline: "iPhoneを、\n自宅のNASへ。",
            subtitle: "NASや自宅サーバーへ、\n安全なSFTPでバックアップ。",
            promo: "暗号化されたSFTP接続で、写真やファイルをNASや自宅サーバーへ直接バックアップ。スケジュールを設定すれば、あとはBackupFlowにおまかせ。"),
        "Korece": PageText(headline: "iPhone을,\n내 NAS로.",
            subtitle: "NAS 또는 홈 서버로\n안전한 SFTP 백업.",
            promo: "암호화된 SFTP 연결로 사진과 파일을 NAS나 홈 서버에 바로 백업하세요. 일정만 정하면 나머지는 BackupFlow가 알아서 합니다."),
        "Çince": PageText(headline: "把 iPhone\n备份到你的 NAS。",
            subtitle: "通过安全的 SFTP\n备份到 NAS 或家庭服务器。",
            promo: "通过加密的 SFTP 连接，将照片和文件直接备份到 NAS 或家庭服务器。设定好计划，其余交给 BackupFlow。"),
    ]),
    Page(slug: "3-kisisel-bulut-webdav", name: "Kişisel Bulut (WebDAV)",
         bannerShots: [4, 8, 1], screenshotOrder: [8, 4, 1, 3, 9, 2], texts: [
        "Türkçe": PageText(headline: "Kendi bulutunuz, kendi kurallarınız.",
            subtitle: "WebDAV destekleyen her sunucuya yedekleyin: kişisel bulut, NAS veya hosting.",
            promo: "Kendi bulutunuzu mu kullanıyorsunuz? BackupFlow, fotoğraf ve dosyalarınızı WebDAV destekleyen her sunucuya otomatik yedekler; yükleme arka planda sürer."),
        "İngilizce": PageText(headline: "Your own cloud. Your rules.",
            subtitle: "Back up to any WebDAV server: personal cloud, NAS or web hosting.",
            promo: "Running your own cloud? BackupFlow automatically backs up photos and files to any WebDAV server, and uploads keep going in the background."),
        "Almanca": PageText(headline: "Deine eigene Cloud. Deine Regeln.",
            subtitle: "Backups auf jeden WebDAV-Server – private Cloud, NAS oder Webhosting.",
            promo: "Du betreibst deine eigene Cloud? BackupFlow sichert Fotos und Dateien automatisch auf jeden WebDAV-Server – der Upload läuft im Hintergrund weiter."),
        "İspanyolca": PageText(headline: "Tu propia nube. Tus reglas.",
            subtitle: "Copia en cualquier servidor WebDAV: nube personal, NAS o hosting.",
            promo: "¿Tienes tu propia nube? BackupFlow copia automáticamente fotos y archivos en cualquier servidor WebDAV, y la subida continúa en segundo plano."),
        "Fransızca": PageText(headline: "Votre cloud. Vos règles.",
            subtitle: "Sauvegarde vers tout serveur WebDAV : cloud personnel, NAS ou hébergement.",
            promo: "Vous gérez votre propre cloud ? BackupFlow sauvegarde automatiquement photos et fichiers sur tout serveur WebDAV, et l'envoi se poursuit en arrière-plan."),
        "Portekizce": PageText(headline: "Sua própria nuvem. Suas regras.",
            subtitle: "Backup em qualquer servidor WebDAV: nuvem pessoal, NAS ou hospedagem.",
            promo: "Tem sua própria nuvem? O BackupFlow faz backup automático de fotos e arquivos em qualquer servidor WebDAV, e o envio continua em segundo plano."),
        "Rusça": PageText(headline: "Ваше облако. Ваши правила.",
            subtitle: "Резервные копии на любой WebDAV-сервер: личное облако, NAS или хостинг.",
            promo: "У вас своё облако? BackupFlow автоматически сохраняет фото и файлы на любой WebDAV-сервер, а загрузка продолжается в фоне."),
        "Arapça": PageText(headline: "سحابتك الخاصة. بقواعدك.",
            subtitle: "نسخ احتياطي إلى أي خادم WebDAV: سحابة شخصية أو NAS أو استضافة.",
            promo: "هل لديك سحابتك الخاصة؟ ينسخ BackupFlow الصور والملفات احتياطيًا تلقائيًا إلى أي خادم WebDAV، ويستمر الرفع في الخلفية."),
        "Hintçe": PageText(headline: "आपका अपना क्लाउड,\nआपके नियम।",
            subtitle: "किसी भी WebDAV सर्वर पर बैकअप: पर्सनल क्लाउड, NAS या होस्टिंग।",
            promo: "अपना क्लाउड चलाते हैं? BackupFlow फ़ोटो और फ़ाइलों का किसी भी WebDAV सर्वर पर अपने-आप बैकअप लेता है, और अपलोड बैकग्राउंड में जारी रहता है।"),
        "Japonca": PageText(headline: "自分だけのクラウドを、\n自分のルールで。",
            subtitle: "WebDAV対応サーバーならどこへでも。\n個人クラウド、NAS、レンタルサーバー。",
            promo: "自分のクラウドを運用中なら、BackupFlowが写真やファイルをWebDAV対応サーバーへ自動バックアップ。アップロードはバックグラウンドで続きます。"),
        "Korece": PageText(headline: "나만의 클라우드,\n나만의 방식으로.",
            subtitle: "모든 WebDAV 서버로 백업:\n개인 클라우드, NAS, 웹 호스팅.",
            promo: "직접 클라우드를 운영하시나요? BackupFlow가 사진과 파일을 모든 WebDAV 서버에 자동으로 백업하며, 업로드는 백그라운드에서 계속됩니다."),
        "Çince": PageText(headline: "你的私有云，\n你说了算。",
            subtitle: "备份到任何 WebDAV 服务器：\n私有云、NAS 或网站主机。",
            promo: "自建了私有云？BackupFlow 可将照片和文件自动备份到任何 WebDAV 服务器，上传在后台持续进行。"),
    ]),
    Page(slug: "4-otomatik-yedekleme", name: "Otomatik Yedekleme",
         bannerShots: [3, 9, 1], screenshotOrder: [9, 1, 2, 3, 5, 4], texts: [
        "Türkçe": PageText(headline: "Bir kez ayarlayın, unutun.",
            subtitle: "Günlük, haftalık veya aylık otomatik yedekleme; isterseniz yalnızca Wi-Fi'de veya şarjdayken.",
            promo: "Zamanlamayı bir kez seçin; BackupFlow her gün, hafta ya da ay yedeğinizi alsın. Yedeklemeyi Wi-Fi, şarj veya belirlediğiniz saat aralığıyla sınırlayın."),
        "İngilizce": PageText(headline: "Set it and forget it.",
            subtitle: "Daily, weekly or monthly backups, only on Wi-Fi or while charging if you like.",
            promo: "Pick a schedule once and BackupFlow backs up every day, week or month. Limit backups to Wi-Fi, charging or a time window you choose."),
        "Almanca": PageText(headline: "Einmal einstellen. Fertig.",
            subtitle: "Tägliche, wöchentliche oder monatliche Backups – auf Wunsch nur im WLAN oder beim Laden.",
            promo: "Einmal einen Zeitplan wählen – BackupFlow sichert täglich, wöchentlich oder monatlich. Backups auf WLAN, Laden oder ein Zeitfenster deiner Wahl beschränken."),
        "İspanyolca": PageText(headline: "Configúralo y olvídate.",
            subtitle: "Copias diarias, semanales o mensuales; si quieres, solo con Wi-Fi o mientras carga.",
            promo: "Elige un horario una vez y BackupFlow hará la copia cada día, semana o mes. Limita las copias al Wi-Fi, a la carga o a la franja horaria que elijas."),
        "Fransızca": PageText(headline: "Réglez-le, oubliez-le.",
            subtitle: "Sauvegardes quotidiennes, hebdomadaires ou mensuelles ; en Wi-Fi ou en charge si vous le souhaitez.",
            promo: "Choisissez une fois un calendrier : BackupFlow sauvegarde chaque jour, semaine ou mois. Limitez les sauvegardes au Wi-Fi, à la recharge ou à une plage horaire."),
        "Portekizce": PageText(headline: "Configure e esqueça.",
            subtitle: "Backups diários, semanais ou mensais; se quiser, só no Wi-Fi ou carregando.",
            promo: "Escolha um horário uma vez e o BackupFlow faz o backup todo dia, semana ou mês. Limite os backups ao Wi-Fi, ao carregamento ou a uma faixa de horário."),
        "Rusça": PageText(headline: "Настройте и забудьте.",
            subtitle: "Ежедневные, еженедельные или ежемесячные копии — по желанию только по Wi-Fi или на зарядке.",
            promo: "Задайте расписание один раз — BackupFlow будет делать копии каждый день, неделю или месяц. Ограничьте их Wi-Fi, зарядкой или удобным временем."),
        "Arapça": PageText(headline: "اضبطه وانسَه.",
            subtitle: "نسخ احتياطي يومي أو أسبوعي أو شهري، عبر Wi-Fi فقط أو أثناء الشحن إن أردت.",
            promo: "اختر جدولًا مرة واحدة، وسيأخذ BackupFlow نسخة احتياطية كل يوم أو أسبوع أو شهر. قيّد النسخ بشبكة Wi-Fi أو الشحن أو نطاق زمني تختاره."),
        "Hintçe": PageText(headline: "एक बार सेट करें,\nफिर भूल जाएँ।",
            subtitle: "रोज़ाना, साप्ताहिक या मासिक बैकअप — चाहें तो सिर्फ़ Wi-Fi पर या चार्जिंग के दौरान।",
            promo: "एक बार शेड्यूल चुनें, BackupFlow हर दिन, हफ़्ते या महीने बैकअप लेगा। बैकअप को Wi-Fi, चार्जिंग या अपनी चुनी हुई समय-सीमा तक सीमित करें।"),
        "Japonca": PageText(headline: "一度設定すれば、\nあとはおまかせ。",
            subtitle: "毎日・毎週・毎月の自動バックアップ。\nWi-Fi接続時や充電中だけにも設定可能。",
            promo: "スケジュールを一度決めるだけで、BackupFlowが毎日・毎週・毎月バックアップ。Wi-Fi接続時、充電中、指定した時間帯だけに限定することもできます。"),
        "Korece": PageText(headline: "한 번 설정하면,\n끝.",
            subtitle: "매일, 매주, 매월 자동 백업.\n원하면 Wi-Fi 연결 시나 충전 중에만.",
            promo: "일정을 한 번만 정하면 BackupFlow가 매일, 매주 또는 매월 백업합니다. Wi-Fi, 충전 중 또는 원하는 시간대로 백업을 제한할 수 있습니다."),
        "Çince": PageText(headline: "设置一次，\n从此无忧。",
            subtitle: "每日、每周或每月自动备份，\n可设为仅在 Wi-Fi 或充电时进行。",
            promo: "只需设定一次计划，BackupFlow 就会每天、每周或每月自动备份。还可限定仅在 Wi-Fi、充电时或指定时段内进行。"),
    ]),
]

let fm = FileManager.default
let checkOnly = CommandLine.arguments.contains("--check")
let onlyLang = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") }
var readme = "# Özel Ürün Sayfaları (Custom Product Pages)\n\n"
readme += "Her sayfa: `screenshots/` (yükleme sırasıyla), `header/` (5244×2950 PNG; Header ve Search Results), tanıtım metni (aşağıda).\n\n"

for page in pages {
    readme += "## \(page.name)\n\nKlasör: `\(page.slug)/`  \nEkran görüntüsü sırası (orijinal numaralar): \(page.screenshotOrder.map(String.init).joined(separator: ", "))\n\n"
    readme += "| Dil | Tanıtım metni (Promotional Text) |\n|---|---|\n"
    for lang in langs {
        guard let t = page.texts[lang.file] else { fatalError("\(page.slug): missing \(lang.file)") }
        if t.promo.count > 170 { print("TOO LONG (\(t.promo.count)) \(page.slug) \(lang.file)") }
        readme += "| \(lang.file) | \(t.promo) |\n"
        if checkOnly || (onlyLang != nil && onlyLang != lang.file) { continue }

        let shotsOut = "\(pagesDir)/\(page.slug)/screenshots"
        let headerOut = "\(pagesDir)/\(page.slug)/header"
        try? fm.createDirectory(atPath: shotsOut, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: headerOut, withIntermediateDirectories: true)
        for (i, n) in page.screenshotOrder.enumerated() {
            let dst = "\(shotsOut)/\(lang.file)\(i + 1).jpg"
            try? fm.removeItem(atPath: dst)
            try! fm.copyItem(atPath: "\(shotsDir)/\(lang.file)\(n).jpg", toPath: dst)
        }
        // Non-breaking hyphen so "Wi-Fi" never wraps at the dash.
        let nb: (String) -> String = { $0.replacingOccurrences(of: "Wi-Fi", with: "Wi\u{2011}Fi") }
        let pageLang = Lang(file: lang.file, headline: nb(t.headline), subtitle: nb(t.subtitle), rtl: lang.rtl)
        let data = render(pageLang, sizes[0], shotIDs: page.bannerShots)
        try! data.write(to: URL(fileURLWithPath: "\(headerOut)/\(lang.file)-5244x2950.png"))
        print(page.slug, lang.file)
    }
    readme += "\n"
}
if !checkOnly {
    try! readme.write(toFile: "\(pagesDir)/README.md", atomically: true, encoding: .utf8)
}
