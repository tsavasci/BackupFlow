# -*- coding: utf-8 -*-
"""Localized documentation content (Part 2: ar, zh, ko, ja, pt, hi) for BackupFlow v4.7."""

DOCS_PART_2 = {
    "ar": {
        "title": "مساعدة وتوثيق BackupFlow",
        "description": "الدليل الكامل لتطبيق BackupFlow على iOS: مركز النسخ الاحتياطي، إعداد FTP/SFTP/WebDAV، نسخ مكتبة الصور والملفات، الجدولة، سياسات الحذف وحل المشكلات.",
        "h1": "مساعدة BackupFlow",
        "lead": "ينسخ BackupFlow صور ومقاطع فيديو وملفات iPhone احتياطيًا مباشرةً إلى خادمك الخاص — جهاز NAS أو خادم منزلي أو سحابتك الشخصية — عبر FTP أو SFTP أو WebDAV. بدون اشتراكات وبدون سحابة طرف ثالث.",
        "toc_title": "في هذه الصفحة",
        "sections": [
            (
                "what-you-need",
                "1. ما تحتاج إليه",
                """<ul>
<li><b>خادم متوافق</b>: أي جهاز NAS (مثل Synology أو QNAP أو TrueNAS أو Unraid) أو خادم منزلي أو سحابة شخصية (Nextcloud أو ownCloud أو WebDAV) يدعم <b>FTP</b> أو <b>SFTP (SSH)</b> أو <b>WebDAV (HTTP/HTTPS)</b>.</li>
<li><b>بيانات الاتصال</b>: عنوان الخادم، ورقم المنفذ (افتراضيًا: FTP <b>21</b>، وSFTP <b>22</b>، وWebDAV <b>443</b>/<b>80</b>)، و<b>اسم المستخدم</b> و<b>كلمة المرور</b> (أو تسجيل الدخول المجهول لـ FTP).</li>
<li><b>أذونات iOS</b>: الوصول الكامل إلى <b>الصور</b>، وإذن <b>الشبكة المحلية</b> (إذا كان الخادم على شبكتك المنزلية)، و<b>الإشعارات</b>.</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. نظرة عامة على مركز النسخ الاحتياطي",
                """<p>عند فتح التطبيق، يعرض لك <b>مركز النسخ الاحتياطي</b> نظرة شاملة وفورية على نظام النسخ الاحتياطي لديك:</p>
<ul>
<li><b>بطاقة الحالة</b>: تعرض وقت آخر مزامنة، وموعد المهمة التالية، وحالة الحماية الحالية، وعنوان الخادم النشط، مع زر <b>التشغيل الأخضر (▶)</b> لبدء نسخة احتياطية فورًا.</li>
<li><b>صحة النسخ الاحتياطي</b>: تعرض نسبة النجاح، وعدد الإخفاقات المتتالية، وتاريخ آخر نسخة ناجحة، ومتوسط المدة.</li>
<li><b>الخوادم المحفوظة</b>: بطاقات ملونة لجميع مهام <b>FTP</b> و<b>SFTP</b> و<b>WebDAV</b> مع أزرار سريعة من أجل <b>التعديل (✏️)</b> أو <b>الحذف (🗑️)</b>. اضغط على أي بطاقة لفتح <b>تفاصيل المهمة</b>.</li>
<li><b>الشريط السفلي والإعدادات</b>: استخدم الأزرار الثلاثة في الأسفل من أجل <b>المزامنة/التشغيل (🔄)</b>، أو فتح <b>سجل النسخ الاحتياطي (🕒)</b>، أو إنشاء <b>نسخة احتياطية جديدة (+)</b>. وتفتح أيقونة <b>الترس (⚙️)</b> في الأعلى <b>الإعدادات</b>.</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. إنشاء نسخة احتياطية جديدة",
                """<p>اضغط على زر <b>+</b> أسفل <b>مركز النسخ الاحتياطي</b> (أو <b>إضافة</b> بجانب <b>الخوادم المحفوظة</b>) لفتح شاشة <b>نسخة احتياطية جديدة</b>:</p>
<ol>
<li><b>المصدر</b>: اختر <b>مكتبة الصور</b> (الصور فقط، أو الفيديو فقط، أو كلاهما) أو اضغط <b>اختر مجلد</b> لاختيار أي مجلد من تطبيق <b>الملفات</b> في iOS.</li>
<li><b>نوع الهدف</b>: اختر <b>FTP</b> أو <b>SFTP</b> أو <b>WebDAV</b>. أدخل عنوان الخادم، والمنفذ، و<b>اسم المستخدم</b>، و<b>كلمة المرور</b>، والمسار البعيد (مثل <code>/remote.php/dav/files/</code>). اضغط <b>اختبار الاتصال</b> للتحقق، ثم اضغط اختياريًا <b>تصفح المجلد البعيد</b> لاختيار مجلد الوجهة.</li>
<li><b>الجدولة</b>: اختر <b>يدوي</b> أو <b>يومياً</b> أو <b>أسبوعياً</b> أو <b>شهري</b> أو <b>فاصل</b>، وحدد الوقت ضمن <b>حدد الوقت</b>.</li>
<li><b>سلوك النسخ الاحتياطي</b>: اضبط <b>سياسة الحذف</b> و<b>المجموع الاختباري</b> وشروط الشبكة والطاقة، ثم احفظ المهمة.</li>
</ol>
<p>بعد اكتمال النسخة الاحتياطية الأولى، يرسل BackupFlow الملفات الجديدة أو المعدّلة فقط، مما يجعل النسخ التالية أسرع بكثير.</p>""",
            ),
            (
                "task-details",
                "4. تفاصيل المهمة وإدارتها",
                """<p>اضغط على أي بطاقة ضمن <b>الخوادم المحفوظة</b> لفتح <b>تفاصيل المهمة</b>:</p>
<ul>
<li><b>عام</b>: عرض المصدر، والحالة الحالية، والجدولة، و<b>سياسة الحذف</b>، وإعداد <b>المجموع الاختباري</b>.</li>
<li><b>الخادم</b>: مراجعة عنوان الخادم والمنفذ واسم المستخدم.</li>
<li><b>النسخ الاحتياطية الأخيرة</b>: عرض أحدث عمليات النسخ لهذه المهمة مع التاريخ والحالة وعدد الملفات والحجم والمدة.</li>
<li>اضغط على <b>تعديل</b> لتحديث إعدادات المهمة في أي وقت.</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. الجدولة وشروط التشغيل",
                """<p>في قسم <b>الجدولة</b> يمكنك الاختيار بين: <b>يدوي</b>، أو <b>يومياً</b>، أو <b>أسبوعياً</b>، أو <b>شهري</b>، أو <b>فاصل</b>، مع تحديد الوقت في <b>حدد الوقت</b>.</p>
<p>ضمن <b>سلوك النسخ الاحتياطي</b> يمكنك تقييد متى يُسمح بتشغيل النسخ التلقائي:</p>
<ul>
<li><b>يتطلب Wi-Fi</b>: يمنع استخدام بيانات الجوال تمامًا.</li>
<li><b>يتطلب طاقة خارجية</b>: يعمل فقط أثناء توصيل iPhone بالشاحن.</li>
<li><b>استخدام نافذة الوقت المسموح بها</b>: يحصر النسخ التلقائي في فترة زمنية محددة (مثل الليل).</li>
<li><b>الحد الأدنى لمستوى البطارية</b> (في <b>الإعدادات › إعدادات البطارية</b>): يؤجل النسخ عند انخفاض شحن البطارية.</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. سياسة الحذف والمجموع الاختباري وiCloud",
                """<p>ضمن <b>سلوك النسخ الاحتياطي</b>، تحدد كيفية التعامل مع الملفات المحذوفة والتحقق من سلامة الملفات:</p>
<dl>
<dt>سياسة الحذف › إضافة فقط</dt>
<dd>لا يُحذف أي شيء من الخادم أبدًا. <b>موصى به</b> إذا كنت تخطط لحذف الصور من iPhone لتوفير المساحة مع الاحتفاظ بها على خادمك.</dd>
<dt>سياسة الحذف › مرآة</dt>
<dd>يبقى مجلد الخادم نسخة مطابقة للمصدر؛ الملفات المحذوفة على iPhone تُحذف من الخادم أيضًا.</dd>
<dt>سياسة الحذف › حذف مع الأرشفة</dt>
<dd>تُنقل الملفات المحذوفة على iPhone إلى مجلد مؤرخ باسم <b>.backupflow_archive</b> على الخادم بدلًا من حذفها نهائيًا.</dd>
<dt>المجموع الاختباري (Checksum)</dt>
<dd>يتحقق من سلامة كل ملف بعد رفعه للتأكد من وصوله كاملًا دون تلف (افتراضيًا <b>إيقاف</b> لأقصى سرعة).</dd>
</dl>
<p class="note"><b>نصيحة لصور iCloud:</b> فعّل خيار <b>تنزيل عناصر iCloud عند الحاجة</b> لنسخ الصور ومقاطع الفيديو الأصلية المخزنة في iCloud فقط.</p>""",
            ),
            (
                "background",
                "7. النسخ الاحتياطي في الخلفية",
                """<p>يتكامل BackupFlow مع نظام <b>BGTaskScheduler</b> في iOS لتشغيل النسخ الاحتياطية المجدولة. نظرًا لأن iOS يتحكم في توقيت المهام الخلفية حسب البطارية واستخدام الجهاز، قد تبدأ المهمة بعد الوقت المحدد بقليل أو ترسل إشعارًا.</p>
<p>إذا أوقف iOS النقل مؤقتًا، افتح BackupFlow ليستأنف العملية تلقائيًا مع تخطي الملفات التي رُفعت مسبقًا. للنسخة الأولى الكبيرة، أبقِ iPhone متصلًا بـ Wi-Fi وبالشاحن.</p>""",
            ),
            (
                "history",
                "8. سجل النسخ الاحتياطي",
                """<p>اضغط على زر <b>السجل (🕒)</b> الأوسط في الشريط السفلي من <b>مركز النسخ الاحتياطي</b>:</p>
<ul>
<li><b>بطاقات الملخص</b>: تعرض إجمالي المهام المكتملة، والفاشلة، وإجمالي البيانات المنقولة (جيجابايت/ميجابايت).</li>
<li><b>سجلات مفصلة</b>: تعرض كل بطاقة اسم المهمة والتاريخ والحالة وعدد الملفات والحجم والمدة. وتتيح أيقونة <b>سلة المهملات (🗑️)</b> في الأعلى مسح السجل.</li>
</ul>""",
            ),
            (
                "settings",
                "9. إعدادات التطبيق",
                """<p>اضغط على أيقونة <b>الترس (⚙️)</b> أعلى <b>مركز النسخ الاحتياطي</b> لفتح <b>الإعدادات</b>:</p>
<ul>
<li><b>الاحتفاظ بالسجل (أيام)</b>: تحديد مدة الاحتفاظ بالسجل (مثل <b>30 يومًا</b>).</li>
<li><b>يتطلب طاقة خارجية</b> و<b>إعدادات البطارية</b>: قواعد الطاقة والحد الأدنى للبطارية.</li>
<li><b>اللغة</b>: تغيير لغة واجهة التطبيق فورًا بين 12 لغة مدعومة.</li>
<li><b>حول</b>: عرض رقم <b>الإصدار</b>، أو الضغط على <b>تقييم التطبيق</b>، أو <b>اتصل بالدعم</b>.</li>
<li><b>إعادة تعيين جميع البيانات</b>: يحذف جميع المهام والسجل وكلمات المرور المحفوظة من هذا الجهاز دون المساس بملفاتك على خوادمك.</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. حل المشكلات",
                """<dl>
<dt>لا أستطيع الاتصال بالخادم.</dt>
<dd>تحقق من العنوان والمنفذ (FTP 21، وSFTP 22، وWebDAV 443/80) واسم المستخدم وكلمة المرور. للخادم المنزلي، تأكد من اتصال iPhone بنفس شبكة Wi-Fi وتفعيل الإذن في <b>إعدادات iPhone › الخصوصية والأمن › الشبكة المحلية › BackupFlow</b>.</dd>
<dt>لم تعمل النسخة المجدولة.</dt>
<dd>تحقق من شروط <b>سلوك النسخ الاحتياطي</b> (Wi-Fi، الطاقة، نافذة الوقت، البطارية) وتفعيل إشعارات التطبيق.</dd>
<dt>بعض الصور مفقودة.</dt>
<dd>تأكد من منح الوصول الكامل للصور وتفعيل <b>تنزيل عناصر iCloud عند الحاجة</b>.</dd>
<dt>اختفت ملفات من الخادم.</dt>
<dd>غيّر <b>سياسة الحذف</b> من <b>مرآة</b> إلى <b>إضافة فقط</b> أو <b>حذف مع الأرشفة</b>.</dd>
<dt>تحذير أمان SFTP.</dt>
<dd>تغيّرت بصمة SSH للخادم. هذا طبيعي إذا أُعيد تثبيت الخادم؛ وإلا فتحقق مع مسؤول الخادم.</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. الخصوصية والأمان",
                """<p>تنتقل ملفاتك مباشرة من iPhone إلى خادمك الخاص. لا يمتلك BackupFlow أي خوادم وسيطة، ولا يطلع على ملفاتك أبدًا، ولا يجمع أي بيانات أو تحليلات. تُحفظ كلمات المرور مشفرة في <b>سلسلة مفاتيح iOS (Keychain)</b>. راجع <a href="../../privacy-policy.html">سياسة الخصوصية</a> الكاملة لمزيد من التفاصيل.</p>""",
            ),
            (
                "help",
                "12. هل تحتاج إلى مساعدة؟",
                """<p>انتقل إلى <b>الإعدادات › اتصل بالدعم</b> داخل التطبيق (أو راسلنا على <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>). يُضاف إصدار التطبيق وطراز الجهاز تلقائيًا إلى الرسالة.</p>""",
            ),
        ],
    },

    "zh": {
        "title": "BackupFlow 帮助与文档",
        "description": "iOS 版 BackupFlow 完整指南：备份中心、FTP/SFTP/WebDAV 配置、照片图库与文件备份、日程安排、删除策略、校验和验证及常见问题解答。",
        "h1": "BackupFlow 帮助",
        "lead": "BackupFlow 可通过 FTP、SFTP 或 WebDAV 将 iPhone 上的照片、视频和文件直接备份到您自己的服务器（NAS、家庭服务器或私有云）。无需订阅，也不经过任何第三方云。",
        "toc_title": "本页内容",
        "sections": [
            (
                "what-you-need",
                "1. 准备工作",
                """<ul>
<li><b>兼容的服务器</b>：任何支持 <b>FTP</b>、<b>SFTP (SSH)</b> 或 <b>WebDAV (HTTP/HTTPS)</b> 的 NAS（群晖 Synology、威联通 QNAP、TrueNAS、Unraid）、家庭服务器或私有云（Nextcloud、ownCloud、WebDAV 存储）。</li>
<li><b>连接信息</b>：服务器地址（IP、域名或完整 WebDAV URL）、端口（默认：FTP <b>21</b>、SFTP <b>22</b>、WebDAV <b>443</b>/<b>80</b>）以及<b>用户名</b>和<b>密码</b>（FTP 也支持<b>匿名登录</b>）。</li>
<li><b>iOS 权限</b>：照片图库的<b>完全访问权限</b>、家庭局域网所需的<b>本地网络</b>权限，以及<b>通知</b>权限。</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. 备份中心概览",
                """<p>打开 BackupFlow 后，<b>备份中心</b>会实时展示您的备份系统状态：</p>
<ul>
<li><b>状态卡片</b>：显示<b>上次同步</b>时间、<b>下一个任务</b>的时间和名称、当前保护状态（<b>安全且已同步</b>）、服务器地址，以及用于立即启动备份的绿色<b>播放 (▶)</b> 按钮。</li>
<li><b>备份健康度</b>：统计备份<b>成功率</b>（百分比与运行次数）、连续<b>失败</b>次数、上次成功备份时间及<b>平均耗时</b>。</li>
<li><b>已保存的服务器</b>：以彩色卡片展示所有已配置的 <b>FTP</b>、<b>SFTP</b> 和 <b>WebDAV</b> 备份任务，支持快速<b>编辑 (✏️)</b> 或<b>删除 (🗑️)</b>。轻点任意卡片即可打开<b>任务详情</b>。</li>
<li><b>底部导航栏与设置</b>：底部三个按钮分别用于<b>同步/运行 (🔄)</b>、打开<b>备份历史 (🕒)</b> 和创建<b>新建备份 (+)</b>。右上角的<b>齿轮图标 (⚙️)</b> 用于打开<b>设置</b>。</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. 创建新建备份",
                """<p>轻点<b>备份中心</b>底部的 <b>+</b> 按钮（或<b>已保存的服务器</b>旁的<b>添加</b>），打开<b>新建备份</b>界面：</p>
<ol>
<li><b>来源</b>：选择<b>照片图库</b>（仅照片、仅视频或照片和视频），或轻点<b>选择文件夹</b>从 iOS“文件”App 中选择任意文件夹。</li>
<li><b>目标类型</b>：选择 <b>FTP</b>、<b>SFTP</b> 或 <b>WebDAV</b>。输入服务器地址、端口、<b>用户名</b>、<b>密码</b>以及远程路径（例如 <code>/remote.php/dav/files/</code>）。轻点<b>测试连接</b>验证无误后，可轻点<b>浏览远程文件夹</b>直接选择服务器上的目标文件夹。</li>
<li><b>日程安排</b>：选择<b>手动</b>、<b>每日</b>、<b>每周</b>、<b>每月</b>或<b>间隔</b>，并在<b>选择时间</b>中设定执行时间。</li>
<li><b>备份行为</b>：设置<b>删除策略</b>、<b>校验和</b>及运行条件，然后保存任务。</li>
</ol>
<p>首次完整备份完成后，BackupFlow 只会传输<b>新增或修改过的文件</b>，因此后续备份速度会快得多。</p>""",
            ),
            (
                "task-details",
                "4. 任务详情与管理",
                """<p>在<b>已保存的服务器</b>下轻点任意任务卡片，即可查看<b>任务详情</b>：</p>
<ul>
<li><b>通用</b>：查看<b>来源</b>、当前<b>状态</b>（如<b>就绪</b>）、<b>日程安排</b>、<b>删除策略</b>和<b>校验和</b>状态。</li>
<li><b>服务器</b>：查看服务器地址、端口和用户名。</li>
<li><b>最近备份</b>：查看该任务的最近执行记录，包括时间、状态、传输文件数、大小和耗时。</li>
<li>轻点左上角的<b>编辑</b>即可随时修改任务配置。</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. 日程安排与运行条件",
                """<p>在<b>日程安排</b>中可选择五种模式：<b>手动</b>、<b>每日</b>、<b>每周</b>、<b>每月</b>或<b>间隔</b>，并在<b>选择时间</b>中指定时间。</p>
<p>在<b>备份行为</b>中可限制自动备份的运行条件：</p>
<ul>
<li><b>需要 Wi-Fi</b>：绝不使用蜂窝移动数据。</li>
<li><b>需要外部电源</b>：仅在 iPhone 连接充电器时运行。</li>
<li><b>使用允许的时间窗口</b>：仅在指定时间段内（如夜间）执行自动备份。</li>
<li><b>最低电池电量</b>（位于<b>设置 › 电池设置</b>）：电量低于阈值时自动跳过备份。</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. 删除策略、校验和与 iCloud",
                """<p>在<b>备份行为</b>中，您可以控制 iPhone 删除文件后服务器端的处理方式以及文件完整性校验：</p>
<dl>
<dt>删除策略 › 仅追加</dt>
<dd>从不删除服务器上的任何文件。如果您打算在备份后删除 iPhone 上的照片以释放空间，<b>强烈建议使用此模式</b>。</dd>
<dt>删除策略 › 镜像</dt>
<dd>使服务器文件夹与 iPhone 来源保持完全一致。在 iPhone 上删除的文件也会在下次同步时从服务器上删除。</dd>
<dt>删除策略 › 归档删除</dt>
<dd>不会永久删除任何内容。在 iPhone 上移除的文件会移至服务器上带日期的 <b>.backupflow_archive</b> 文件夹中。</dd>
<dt>校验和 (Checksum)</dt>
<dd>开启后会在上传完成后校验每个文件的完整性（默认<b>关闭</b>以获得最高传输速度）。</dd>
</dl>
<p class="note"><b>iCloud 照片提示：</b>如果启用了“优化 iPhone 储存空间”，请开启<b>需要时下载 iCloud 项目</b>，以便自动下载并备份仅保存在 iCloud 中的原片。</p>""",
            ),
            (
                "background",
                "7. 后台备份",
                """<p>BackupFlow 集成了 iOS <b>BGTaskScheduler</b> 以执行后台自动备份。由于 iOS 会根据电量、充电状态和使用习惯决定后台运行的具体时刻，计划备份可能会在设定时间之后稍晚启动或发送通知提醒。</p>
<p>如果 iOS 中途暂停了后台传输，只需打开 BackupFlow 即可自动续传，已上传的文件会自动跳过。首次进行大容量备份时，建议让 iPhone 保持连接 Wi-Fi 和充电器。</p>""",
            ),
            (
                "history",
                "8. 备份历史",
                """<p>轻点<b>备份中心</b>底部栏中间的<b>历史 (🕒)</b> 按钮即可打开<b>备份历史</b>：</p>
<ul>
<li><b>汇总卡片</b>：顶部显示<b>已完成</b>次数、<b>失败</b>次数以及累计<b>已传输</b>数据量（GB/MB）。</li>
<li><b>详细记录</b>：每条记录展示任务名称、日期时间、状态标签、<b>文件数</b>（如 <code>1236/1236</code>）、<b>已传输</b>大小和<b>耗时</b>。轻点右上角的<b>垃圾桶图标 (🗑️)</b> 可清空历史记录。</li>
</ul>""",
            ),
            (
                "settings",
                "9. 应用设置",
                """<p>轻点<b>备份中心</b>右上角的<b>齿轮图标 (⚙️)</b> 打开<b>设置</b>：</p>
<ul>
<li><b>历史记录保留期（天）</b>：选择历史记录在设备上的保留天数（如 <b>30 天</b>）。</li>
<li><b>需要外部电源</b>与<b>电池设置</b>：全局充电要求与最低电量阈值设置。</li>
<li><b>语言</b>：在应用内随时切换 12 种支持语言。</li>
<li><b>关于</b>：查看当前<b>版本</b>、轻点<b>评价应用</b>或<b>联系支持</b>。</li>
<li><b>重置所有数据</b>：清除此 iPhone 上的所有任务、历史记录和已保存的密码，服务器上的文件不会受到任何影响。</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. 常见问题排查",
                """<dl>
<dt>无法连接到服务器。</dt>
<dd>请检查服务器地址、端口（FTP 21、SFTP 22、WebDAV 443/80）、用户名和密码。对于家庭局域网服务器，请确认 iPhone 连接在同一 Wi-Fi 下，且已在 <b>iPhone 设置 › 隐私与安全性 › 本地网络 › BackupFlow</b> 中开启权限。</dd>
<dt>计划的备份未执行。</dt>
<dd>请检查任务的<b>备份行为</b>条件（Wi-Fi、电源、时间窗口、电池设置）以及是否已允许 BackupFlow 发送通知。</dd>
<dt>部分照片未备份。</dt>
<dd>请确认已授予照片“完全访问”权限，并开启<b>需要时下载 iCloud 项目</b>。</dd>
<dt>服务器上的文件被删除了。</dt>
<dd>请将任务的<b>删除策略</b>从<b>镜像</b>改为<b>仅追加</b>或<b>归档删除</b>。</dd>
<dt>出现 SFTP 安全警告。</dt>
<dd>服务器的 SSH 指纹发生了变化。如果服务器重装或更换过属于正常情况，否则请先向管理员确认。</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. 隐私与安全",
                """<p>您的文件直接从 iPhone 传输到您自己的服务器。BackupFlow 没有自己的云服务器，从不查看您的文件，也不收集任何个人数据或分析统计。服务器密码加密保存在 <b>iOS 钥匙串 (Keychain)</b> 中。详情请参阅完整<a href="../../privacy-policy.html">隐私政策</a>。</p>""",
            ),
            (
                "help",
                "12. 需要帮助？",
                """<p>请在应用内前往<b>设置 › 联系支持</b>（或发送邮件至 <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>），邮件会自动附上应用版本和设备型号。</p>""",
            ),
        ],
    },

    "ko": {
        "title": "BackupFlow 도움말 및 문서",
        "description": "iOS용 BackupFlow 완벽 가이드: 백업 허브, FTP/SFTP/WebDAV 설정, 사진 보관함 및 파일 백업, 스케줄링, 삭제 정책, 체크섬 확인 및 문제 해결.",
        "h1": "BackupFlow 도움말",
        "lead": "BackupFlow는 iPhone의 사진, 동영상, 파일을 FTP, SFTP 또는 WebDAV를 통해 내 서버(NAS, 홈 서버, 개인 클라우드)로 직접 백업합니다. 구독도, 타사 클라우드도 필요 없습니다.",
        "toc_title": "이 페이지에서",
        "sections": [
            (
                "what-you-need",
                "1. 준비할 것",
                """<ul>
<li><b>호환 서버</b>: <b>FTP</b>, <b>SFTP(SSH)</b> 또는 <b>WebDAV(HTTP/HTTPS)</b>를 지원하는 NAS(Synology, QNAP, TrueNAS, Unraid), 홈 서버 또는 개인 클라우드(Nextcloud, ownCloud, WebDAV).</li>
<li><b>접속 정보</b>: 서버 주소, 포트 번호(기본값: FTP <b>21</b>, SFTP <b>22</b>, WebDAV <b>443</b>/<b>80</b>), <b>사용자 이름</b> 및 <b>비밀번호</b>(FTP는 익명 로그인 지원).</li>
<li><b>iOS 권한</b>: <b>사진</b> 전체 접근 권한, 홈 네트워크 서버 연결을 위한 <b>로컬 네트워크</b> 권한, <b>알림</b> 권한.</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. 백업 허브 둘러보기",
                """<p>앱을 열면 <b>백업 허브</b>에서 전체 백업 상태를 한눈에 확인할 수 있습니다:</p>
<ul>
<li><b>상태 배너</b>: 마지막 동기화 시각, 다음 작업 예정 시각, 현재 보호 상태, 활성 서버 주소 및 즉시 백업을 시작하는 초록색 <b>실행(▶)</b> 버튼을 표시합니다.</li>
<li><b>백업 상태(Health)</b>: 성공률(퍼센트 및 실행 횟수), 연속 실패 횟수, 마지막 성공 일시 및 평균 소요 시간을 보여줍니다.</li>
<li><b>저장된 서버</b>: 설정된 모든 <b>FTP</b>, <b>SFTP</b>, <b>WebDAV</b> 작업 카드를 보여주며, 빠른 <b>편집(✏️)</b> 및 <b>삭제(🗑️)</b> 아이콘을 제공합니다. 카드를 탭하면 <b>작업 상세</b> 화면이 열립니다.</li>
<li><b>하단 바 및 설정</b>: 화면 하단의 버튼 3개로 <b>동기화/실행(🔄)</b>, <b>백업 기록(🕒)</b> 열기, <b>새 백업(+)</b> 만들기를 실행할 수 있습니다. 오른쪽 상단의 <b>톱니바퀴(⚙️)</b> 아이콘은 <b>설정</b>을 엽니다.</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. 새 백업 만들기",
                """<p><b>백업 허브</b> 하단의 <b>+</b> 버튼(또는 <b>저장된 서버</b> 옆의 <b>추가</b>)을 탭해 <b>새 백업</b> 화면을 엽니다:</p>
<ol>
<li><b>원본</b>: <b>사진 보관함</b>(사진만, 동영상만, 또는 사진 및 동영상)을 선택하거나 <b>폴더 선택</b>을 탭해 iOS <b>파일</b> 앱의 폴더를 선택합니다.</li>
<li><b>대상 유형</b>: <b>FTP</b>, <b>SFTP</b> 또는 <b>WebDAV</b>를 선택합니다. 서버 주소, 포트, <b>사용자 이름</b>, <b>비밀번호</b> 및 원격 경로(예: <code>/remote.php/dav/files/</code>)를 입력합니다. <b>연결 테스트</b>로 확인한 뒤 <b>원격 폴더 찾아보기</b>로 대상 폴더를 지정할 수 있습니다.</li>
<li><b>스케줄링</b>: <b>수동</b>, <b>매일</b>, <b>매주</b>, <b>매월</b> 또는 <b>간격</b> 중에서 선택하고 <b>시간 선택</b>에서 실행 시각을 지정합니다.</li>
<li><b>백업 동작</b>: <b>삭제 정책</b>, <b>체크섬</b> 및 실행 조건을 설정한 뒤 작업을 저장합니다.</li>
</ol>
<p>첫 전체 백업이 완료된 후에는 새로 추가되거나 변경된 파일만 전송하므로 다음 백업이 훨씬 빠릅니다.</p>""",
            ),
            (
                "task-details",
                "4. 작업 상세 및 관리",
                """<p><b>저장된 서버</b>에서 카드를 탭하면 <b>작업 상세</b> 화면이 열립니다:</p>
<ul>
<li><b>일반</b>: 원본, 현재 상태(예: 준비됨), 스케줄, <b>삭제 정책</b> 및 <b>체크섬</b> 설정을 확인합니다.</li>
<li><b>서버</b>: 서버 주소, 포트, 사용자 계정을 확인합니다.</li>
<li><b>최근 백업</b>: 해당 작업의 최근 실행 기록(날짜, 완료 여부, 파일 수, 용량, 소요 시간)을 보여줍니다.</li>
<li>왼쪽 상단의 <b>편집</b>을 탭해 언제든 설정을 수정할 수 있습니다.</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. 스케줄링 및 실행 조건",
                """<p><b>스케줄링</b>에서 <b>수동</b>, <b>매일</b>, <b>매주</b>, <b>매월</b>, <b>간격</b> 중 하나를 고르고 <b>시간 선택</b>으로 실행 시각을 정합니다.</p>
<p><b>백업 동작</b>에서 자동 백업이 실행될 조건을 지정할 수 있습니다:</p>
<ul>
<li><b>Wi-Fi 필요</b>: 모바일 데이터를 절대 사용하지 않습니다.</li>
<li><b>외부 전원 필요</b>: iPhone이 충전 중일 때만 실행됩니다.</li>
<li><b>허용 시간대 사용</b>: 지정한 시간대(예: 심야 시간)에만 자동 백업을 허용합니다.</li>
<li><b>최소 배터리 잔량</b>(<b>설정 › 배터리 설정</b>): 배터리가 기준치보다 낮으면 백업을 건너뜁니다.</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. 삭제 정책, 체크섬 및 iCloud",
                """<p><b>백업 동작</b>에서 iPhone에서 삭제한 파일의 처리 방식과 파일 무결성 검사를 설정합니다:</p>
<dl>
<dt>삭제 정책 › 추가만</dt>
<dd>서버의 파일을 절대 삭제하지 않습니다. 백업 후 iPhone 저장 공간을 확보하기 위해 사진을 지울 계획이라면 <b>반드시 이 옵션을 선택하세요</b>.</dd>
<dt>삭제 정책 › 미러</dt>
<dd>서버 폴더를 iPhone 원본과 똑같이 유지합니다. iPhone에서 삭제한 파일은 서버에서도 삭제됩니다.</dd>
<dt>삭제 정책 › 보관 후 삭제</dt>
<dd>삭제된 파일을 영구 삭제하지 않고 서버의 날짜별 <b>.backupflow_archive</b> 폴더로 이동합니다.</dd>
<dt>체크섬 (Checksum)</dt>
<dd>업로드 후 모든 파일이 손상 없이 도착했는지 확인합니다(최대 속도를 위해 기본값은 <b>끔</b>).</dd>
</dl>
<p class="note"><b>iCloud 사진 팁:</b> iCloud 사진을 사용 중이라면 <b>필요한 경우 iCloud 항목 다운로드</b>를 켜서 iCloud에만 보관된 원본 사진과 동영상도 빠짐없이 백업하세요.</p>""",
            ),
            (
                "background",
                "7. 백그라운드 백업",
                """<p>BackupFlow는 iOS <b>BGTaskScheduler</b>와 연동되어 예약된 백업을 실행합니다. iOS가 배터리 및 기기 사용 패턴에 따라 백그라운드 실행 시점을 조율하므로 지정한 시각보다 조금 뒤에 시작되거나 알림을 보낼 수 있습니다.</p>
<p>iOS가 백그라운드 전송을 일시 중지하더라도 앱을 열면 자동으로 이어서 진행되며, 이미 전송된 파일은 건너뜁니다. 첫 대용량 백업 시에는 Wi-Fi와 충전기에 연결해 두세요.</p>""",
            ),
            (
                "history",
                "8. 백업 기록",
                """<p><b>백업 허브</b> 하단 바 가운데의 <b>기록(🕒)</b> 버튼을 탭해 <b>백업 기록</b>을 엽니다:</p>
<ul>
<li><b>요약 카드</b>: 상단에서 총 완료 횟수, 실패 횟수 및 누적 전송 용량(GB/MB)을 확인합니다.</li>
<li><b>상세 실행 기록</b>: 각 항목에 작업 이름, 날짜 및 시간, 완료 배지, 전송된 파일 수(예: <code>1236/1236</code>), 용량 및 소요 시간이 표시됩니다. 오른쪽 상단의 <b>휴지통(🗑️)</b> 아이콘으로 기록을 지울 수 있습니다.</li>
</ul>""",
            ),
            (
                "settings",
                "9. 앱 설정",
                """<p><b>백업 허브</b> 오른쪽 상단의 <b>톱니바퀴(⚙️)</b> 아이콘을 탭해 <b>설정</b>을 엽니다:</p>
<ul>
<li><b>기록 보관 기간(일)</b>: 백업 기록을 보관할 일수를 선택합니다(예: <b>30일</b>).</li>
<li><b>외부 전원 필요</b> 및 <b>배터리 설정</b>: 전체 전원 조건 및 최소 배터리 잔량을 설정합니다.</li>
<li><b>언어</b>: 지원하는 12개 언어 중 원하는 언어로 앱 인터페이스를 즉시 변경합니다.</li>
<li><b>정보</b>: 앱 <b>버전</b> 확인, <b>앱 평가하기</b>, <b>지원 문의</b>를 제공합니다.</li>
<li><b>모든 데이터 초기화</b>: 이 기기에서 모든 작업, 기록 및 저장된 비밀번호를 삭제합니다. 서버에 저장된 파일은 건드리지 않습니다.</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. 문제 해결",
                """<dl>
<dt>서버에 연결할 수 없습니다.</dt>
<dd>주소, 포트(FTP 21, SFTP 22, WebDAV 443/80), 사용자 이름과 비밀번호를 확인하세요. 홈 서버의 경우 같은 Wi-Fi에 연결되어 있는지, <b>iPhone 설정 › 개인정보 보호 및 보안 › 로컬 네트워크 › BackupFlow</b> 권한이 켜져 있는지 확인하세요.</dd>
<dt>예약된 백업이 실행되지 않았습니다.</dt>
<dd><b>백업 동작</b> 조건(Wi-Fi, 외부 전원, 허용 시간대, 배터리)과 알림 허용 여부를 확인하세요.</dd>
<dt>일부 사진이 누락되었습니다.</dt>
<dd>사진 '전체 접근' 권한을 허용하고 <b>필요한 경우 iCloud 항목 다운로드</b>를 켜세요.</dd>
<dt>서버에서 파일이 사라졌습니다.</dt>
<dd>작업의 <b>삭제 정책</b>을 <b>미러</b>에서 <b>추가만</b> 또는 <b>보관 후 삭제</b>로 변경하세요.</dd>
<dt>SFTP 보안 경고가 표시됩니다.</dt>
<dd>서버의 SSH 지문이 변경되었습니다. 서버를 재설치하거나 교체했다면 정상이며, 그렇지 않다면 서버 관리자에게 문의하세요.</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. 개인정보 보호 및 보안",
                """<p>모든 파일은 iPhone에서 사용자의 서버로 직접 전송됩니다. BackupFlow는 자체 클라우드 서버를 운영하지 않으며, 파일을 열람하거나 어떠한 분석·추적 데이터도 수집하지 않습니다. 비밀번호는 <b>iOS 키체인(Keychain)</b>에 안전하게 암호화되어 저장됩니다. 자세한 내용은 <a href="../../privacy-policy.html">개인정보 처리방침</a>을 참고하세요.</p>""",
            ),
            (
                "help",
                "12. 도움이 필요하신가요?",
                """<p>앱 내 <b>설정 › 지원 문의</b>를 탭하거나 <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>으로 이메일을 보내 주세요. 앱 버전과 기기 모델이 자동으로 포함됩니다.</p>""",
            ),
        ],
    },

    "ja": {
        "title": "BackupFlow ヘルプ＆ドキュメント",
        "description": "iOS版 BackupFlow 完全ガイド：バックアップハブ、FTP/SFTP/WebDAV設定、写真ライブラリとファイルのバックアップ、スケジュール、削除ポリシー、チェックサム検証、トラブルシューティング。",
        "h1": "BackupFlow ヘルプ",
        "lead": "BackupFlowは、iPhoneの写真・ビデオ・ファイルをFTP、SFTP、またはWebDAV経由でご自身のサーバー（NAS、自宅サーバー、プライベートクラウド）へ直接バックアップします。サブスクリプションも他社クラウドも不要です。",
        "toc_title": "このページの内容",
        "sections": [
            (
                "what-you-need",
                "1. 必要なもの",
                """<ul>
<li><b>対応サーバー</b>：<b>FTP</b>、<b>SFTP（SSH）</b>、または<b>WebDAV（HTTP/HTTPS）</b>に対応したNAS（Synology、QNAP、TrueNAS、Unraidなど）、自宅サーバー、または個人クラウド（Nextcloud、ownCloud、WebDAVストレージ）。</li>
<li><b>接続情報</b>：サーバーアドレス、ポート番号（標準：FTP <b>21</b>、SFTP <b>22</b>、WebDAV <b>443</b>/<b>80</b>）、<b>ユーザー名</b>と<b>パスワード</b>（FTPは匿名ログインも可）。</li>
<li><b>iOSの権限</b>：<b>写真</b>へのフルアクセス、自宅ネットワーク内サーバー用の<b>ローカルネットワーク</b>権限、および<b>通知</b>。</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. バックアップハブの概要",
                """<p>アプリを開くと、<b>バックアップハブ</b>にバックアップシステムの状態がリアルタイムで表示されます：</p>
<ul>
<li><b>ステータスカード</b>：前回の同期日時、次のタスクの時刻と名前、保護ステータス、サーバーアドレス、そして今すぐバックアップを開始できる緑色の<b>再生（▶）</b>ボタンが表示されます。</li>
<li><b>バックアップの健全性</b>：成功率（％と実行回数）、連続失敗回数、前回の成功日時、平均所要時間を表示します。</li>
<li><b>保存済みサーバー</b>：設定済みの<b>FTP</b>、<b>SFTP</b>、<b>WebDAV</b>タスクがカード表示され、<b>編集（✏️）</b>や<b>削除（🗑️）</b>がすぐに行えます。カードをタップすると<b>タスクの詳細</b>が開きます。</li>
<li><b>下部バーと設定</b>：画面下部の3つのボタンから<b>同期・実行（🔄）</b>、<b>バックアップ履歴（🕒）</b>、<b>新しいバックアップ（+）</b>にアクセスできます。右上の<b>歯車アイコン（⚙️）</b>で<b>設定</b>を開きます。</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. 新しいバックアップを作成する",
                """<p><b>バックアップハブ</b>下部の<b>+</b>ボタン（または<b>保存済みサーバー</b>横の<b>追加</b>）をタップして<b>新しいバックアップ</b>画面を開きます：</p>
<ol>
<li><b>ソース</b>：<b>写真ライブラリ</b>（写真のみ、ビデオのみ、または両方）を選ぶか、<b>フォルダを選択</b>をタップしてiOSの「ファイル」アプリからフォルダを選びます。</li>
<li><b>ターゲットタイプ</b>：<b>FTP</b>、<b>SFTP</b>、<b>WebDAV</b>から選択し、サーバーアドレス、ポート、<b>ユーザー名</b>、<b>パスワード</b>、リモートパス（例：<code>/remote.php/dav/files/</code>）を入力します。<b>接続をテスト</b>で確認し、必要に応じて<b>リモートフォルダを参照</b>から保存先フォルダを選択します。</li>
<li><b>スケジュール</b>：<b>手動</b>、<b>毎日</b>、<b>毎週</b>、<b>毎月</b>、<b>間隔</b>から選び、<b>時間を選択</b>で実行時刻を設定します。</li>
<li><b>バックアップ動作</b>：<b>削除ポリシー</b>、<b>チェックサム</b>、実行条件を設定してタスクを保存します。</li>
</ol>
<p>初回のフルバックアップ完了後は、新しく追加・変更されたファイルのみが転送されるため、2回目以降は大幅に高速化されます。</p>""",
            ),
            (
                "task-details",
                "4. タスクの詳細と管理",
                """<p><b>保存済みサーバー</b>のカードをタップすると<b>タスクの詳細</b>が開きます：</p>
<ul>
<li><b>一般</b>：ソース、現在のステータス（準備完了など）、スケジュール、<b>削除ポリシー</b>、<b>チェックサム</b>設定を確認できます。</li>
<li><b>サーバー</b>：サーバーアドレス、ポート、ユーザー名を確認できます。</li>
<li><b>最近のバックアップ</b>：このタスクの直近の実行履歴（日時、ステータス、ファイル数、サイズ、所要時間）を確認できます。</li>
<li>左上の<b>編集</b>をタップすると設定を変更できます。</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. スケジュールと実行条件",
                """<p><b>スケジュール</b>では<b>手動</b>、<b>毎日</b>、<b>毎週</b>、<b>毎月</b>、<b>間隔</b>を選択でき、<b>時間を選択</b>で時刻を指定できます。</p>
<p><b>バックアップ動作</b>では自動バックアップの実行条件を制限できます：</p>
<ul>
<li><b>Wi-Fiが必要</b>：モバイルデータ通信を一切使用しません。</li>
<li><b>外部電源が必要</b>：iPhoneの充電中のみ実行します。</li>
<li><b>許可された時間帯を使用</b>：夜間など指定した時間帯にのみ自動バックアップを実行します。</li>
<li><b>最小バッテリー残量</b>（<b>設定 › バッテリー設定</b>）：バッテリー残量がしきい値未満のときはスキップします。</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. 削除ポリシー・チェックサム・iCloud",
                """<p><b>バックアップ動作</b>では、iPhoneで削除したファイルのサーバー側での扱いと整合性チェックを設定できます：</p>
<dl>
<dt>削除ポリシー › 追加のみ</dt>
<dd>サーバー上のファイルは一切削除されません。バックアップ後にiPhoneの写真・ビデオを消して空き容量を増やしたい場合は<b>このモードを推奨します</b>。</dd>
<dt>削除ポリシー › ミラー</dt>
<dd>サーバーのフォルダをiPhoneのソースと完全に同じ状態に保ちます。iPhoneで削除したファイルは次回同期時にサーバーからも削除されます。</dd>
<dt>削除ポリシー › アーカイブ削除</dt>
<dd>iPhoneで削除されたファイルは完全には消去されず、サーバー上の日付付き<b>.backupflow_archive</b>フォルダに移動されます。</dd>
<dt>チェックサム (Checksum)</dt>
<dd>アップロード後に各ファイルが破損なくサーバーに届いたか検証します（最高速度のため初期設定は<b>オフ</b>）。</dd>
</dl>
<p class="note"><b>iCloud写真のヒント：</b>「iPhoneのストレージを最適化」をお使いの場合は、<b>必要に応じてiCloud項目をダウンロード</b>をオンにすることで、iCloud上にのみあるオリジナル写真・ビデオもバックアップできます。</p>""",
            ),
            (
                "background",
                "7. バックグラウンドでのバックアップ",
                """<p>BackupFlowはiOSの<b>BGTaskScheduler</b>と連携してスケジュールされたバックアップを実行します。iOSがバッテリー残量や使用状況に応じて実行タイミングを調整するため、指定時刻より少し後に開始されたり通知が届いたりすることがあります。</p>
<p>iOSによって途中で一時停止された場合でも、アプリを開けば続きから再開され、転送済みのファイルはスキップされます。初回の大量バックアップ時はiPhoneをWi-Fiと充電器に接続したままにしてください。</p>""",
            ),
            (
                "history",
                "8. バックアップ履歴",
                """<p><b>バックアップハブ</b>下部バー中央の<b>履歴（🕒）</b>ボタンをタップして<b>バックアップ履歴</b>を開きます：</p>
<ul>
<li><b>サマリーカード</b>：完了数、失敗数、累計転送データ量（GB/MB）を上部に表示します。</li>
<li><b>詳細ログ</b>：各カードにタスク名、日時、完了バッジ、ファイル数（例：<code>1236/1236</code>）、転送サイズ、所要時間が表示されます。右上の<b>ゴミ箱アイコン（🗑️）</b>で履歴を消去できます。</li>
</ul>""",
            ),
            (
                "settings",
                "9. アプリ設定",
                """<p><b>バックアップハブ</b>右上の<b>歯車アイコン（⚙️）</b>から<b>設定</b>を開きます：</p>
<ul>
<li><b>履歴保持期間（日）</b>：履歴を保存する日数（例：<b>30日間</b>）を選択します。</li>
<li><b>外部電源が必要</b>と<b>バッテリー設定</b>：電源およびバッテリー残量の全体ルールを設定します。</li>
<li><b>言語</b>：対応する12言語からアプリの表示言語をいつでも切り替えられます。</li>
<li><b>情報</b>：アプリの<b>バージョン</b>確認、<b>アプリを評価</b>、<b>サポートに連絡</b>が行えます。</li>
<li><b>すべてのデータをリセット</b>：このiPhoneからすべてのタスク、履歴、保存済みパスワードを削除します（サーバー上のファイルは削除されません）。</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. 困ったときは",
                """<dl>
<dt>サーバーに接続できない</dt>
<dd>アドレス、ポート（FTP 21、SFTP 22、WebDAV 443/80）、ユーザー名、パスワードを確認してください。自宅サーバーの場合は同じWi-Fiに接続し、<b>iPhoneの設定 › プライバシーとセキュリティ › ローカルネットワーク › BackupFlow</b>がオンになっているか確認してください。</dd>
<dt>予定したバックアップが実行されない</dt>
<dd><b>バックアップ動作</b>の条件（Wi-Fi、外部電源、時間帯、バッテリー）と通知の許可を確認してください。</dd>
<dt>一部の写真が含まれない</dt>
<dd>写真への「フルアクセス」を許可し、<b>必要に応じてiCloud項目をダウンロード</b>をオンにしてください。</dd>
<dt>サーバーからファイルが消えた</dt>
<dd>タスクの<b>削除ポリシー</b>を<b>ミラー</b>から<b>追加のみ</b>または<b>アーカイブ削除</b>に変更してください。</dd>
<dt>SFTPのセキュリティ警告が表示される</dt>
<dd>サーバーのSSHフィンガープリントが変更されました。サーバーの再インストールや交換時は正常ですが、それ以外は管理者に確認してください。</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. プライバシーとセキュリティ",
                """<p>ファイルはiPhoneからご自身のサーバーへ直接転送されます。BackupFlowは独自のサーバーを持たず、ファイルを見ることも分析・追跡データを収集することもありません。パスワードは<b>iOSキーチェーン（Keychain）</b>に暗号化して保存されます。詳細は<a href="../../privacy-policy.html">プライバシーポリシー</a>をご覧ください。</p>""",
            ),
            (
                "help",
                "12. お問い合わせ",
                """<p>アプリ内の<b>設定 › サポートに連絡</b>（または <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>）からメールをお送りください。アプリのバージョンとデバイスモデルが自動的に添付されます。</p>""",
            ),
        ],
    },

    "pt": {
        "title": "Ajuda e Documentação do BackupFlow",
        "description": "Guia completo do BackupFlow para iOS: Central de backup, configuração FTP/SFTP/WebDAV, backup da Biblioteca de Fotos e Arquivos, agendamento, políticas de exclusão e solução de problemas.",
        "h1": "Ajuda do BackupFlow",
        "lead": "O BackupFlow faz backup das fotos, vídeos e arquivos do seu iPhone diretamente no seu próprio servidor — NAS, servidor doméstico ou nuvem pessoal — via FTP, SFTP ou WebDAV. Sem assinaturas e sem nuvens de terceiros.",
        "toc_title": "Nesta página",
        "sections": [
            (
                "what-you-need",
                "1. Do que você precisa",
                """<ul>
<li><b>Um servidor compatível</b>: Qualquer NAS (Synology, QNAP, TrueNAS, Unraid), servidor doméstico ou nuvem pessoal (Nextcloud, ownCloud, WebDAV) compatível com <b>FTP</b>, <b>SFTP (SSH)</b> ou <b>WebDAV (HTTP/HTTPS)</b>.</li>
<li><b>Dados de acesso</b>: Endereço do servidor, porta (FTP <b>21</b>, SFTP <b>22</b>, WebDAV <b>443</b>/<b>80</b>), <b>Nome de usuário</b> e <b>Senha</b> (ou login anônimo para FTP).</li>
<li><b>Permissões do iOS</b>: Acesso total a <b>Fotos</b>, permissão de <b>Rede Local</b> (para servidores domésticos) e <b>Notificações</b>.</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. Visão geral da Central de backup",
                """<p>Ao abrir o BackupFlow, a <b>Central de backup</b> mostra o status completo do seu sistema em tempo real:</p>
<ul>
<li><b>Cartão de status</b>: Mostra a última sincronização, o horário da próxima tarefa, o status de proteção, o endereço do servidor e o botão verde <b>Reproduzir (▶)</b> para iniciar um backup imediatamente.</li>
<li><b>Saúde do backup</b>: Exibe a taxa de sucesso, falhas consecutivas, data do último backup bem-sucedido e duração média.</li>
<li><b>Servidores salvos</b>: Cartões para suas tarefas <b>FTP</b>, <b>SFTP</b> e <b>WebDAV</b> com atalhos para <b>Editar (✏️)</b> e <b>Excluir (🗑️)</b>. Toque em qualquer cartão para abrir os <b>Detalhes da Tarefa</b>.</li>
<li><b>Barra inferior e Configurações</b>: Use os três botões inferiores para <b>Sincronizar (🔄)</b>, abrir o <b>Histórico de Backup (🕒)</b> ou criar um <b>Novo Backup (+)</b>. O ícone de <b>engrenagem (⚙️)</b> no canto superior direito abre as <b>Configurações</b>.</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. Criar um Novo Backup",
                """<p>Toque no botão <b>+</b> na barra inferior da <b>Central de backup</b> (ou em <b>Adicionar</b> ao lado de <b>Servidores salvos</b>) para abrir a tela <b>Novo Backup</b>:</p>
<ol>
<li><b>Origem</b>: Escolha <b>Biblioteca de Fotos</b> (somente fotos, somente vídeos ou ambos) ou toque em <b>Selecionar pasta</b> para escolher qualquer pasta do app <b>Arquivos</b> do iOS.</li>
<li><b>Tipo de destino</b>: Selecione <b>FTP</b>, <b>SFTP</b> ou <b>WebDAV</b>. Informe o endereço do servidor, a porta, o <b>Nome de usuário</b>, a <b>Senha</b> e o caminho remoto (ex.: <code>/remote.php/dav/files/</code>). Toque em <b>Testar Conexão</b> e, se desejar, em <b>Procurar pasta remota</b> para escolher a pasta no servidor.</li>
<li><b>Agendamento</b>: Escolha <b>Manual</b>, <b>Diário</b>, <b>Semanal</b>, <b>Mensal</b> ou <b>Intervalo</b> e defina o horário em <b>Selecionar Horário</b>.</li>
<li><b>Comportamento do backup</b>: Configure a <b>Política de exclusão</b>, a <b>Soma de verificação</b> e as condições de execução, e salve a tarefa.</li>
</ol>
<p>Após o primeiro backup completo, apenas arquivos novos ou alterados são enviados, tornando os backups seguintes muito mais rápidos.</p>""",
            ),
            (
                "task-details",
                "4. Detalhes e gerenciamento da tarefa",
                """<p>Toque em qualquer tarefa em <b>Servidores salvos</b> para abrir os <b>Detalhes da Tarefa</b>:</p>
<ul>
<li><b>Geral</b>: Veja a origem, o status atual, o agendamento, a <b>Política de exclusão</b> e a <b>Soma de verificação</b>.</li>
<li><b>Servidor</b>: Confira o endereço do servidor, a porta e o usuário.</li>
<li><b>Backups recentes</b>: Veja as últimas execuções dessa tarefa com data, status, quantidade de arquivos, tamanho e duração.</li>
<li>Toque em <b>Editar</b> no canto superior esquerdo para alterar qualquer configuração.</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. Agendamento e condições",
                """<p>Em <b>Agendamento</b>, escolha entre <b>Manual</b>, <b>Diário</b>, <b>Semanal</b>, <b>Mensal</b> ou <b>Intervalo</b>, definindo o horário em <b>Selecionar Horário</b>.</p>
<p>Em <b>Comportamento do backup</b>, defina quando o backup automático pode rodar:</p>
<ul>
<li><b>Requer Wi-Fi</b>: Nunca utiliza dados móveis.</li>
<li><b>Requer energia externa</b>: Executa apenas enquanto o iPhone está carregando.</li>
<li><b>Usar janela de horário permitida</b>: Restringe backups automáticos a um horário específico (por exemplo, durante a noite).</li>
<li><b>Nível Mínimo da Bateria</b> (em <b>Configurações › Configurações de Bateria</b>): Pula o backup se a bateria estiver baixa.</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. Política de exclusão, Soma de verificação e iCloud",
                """<p>Em <b>Comportamento do backup</b>, você controla o que acontece no servidor quando apaga arquivos no iPhone e a verificação de integridade:</p>
<dl>
<dt>Política de exclusão › Somente adicionar</dt>
<dd>Nada é apagado do servidor. <b>Recomendado</b> se você pretende apagar fotos/vídeos do iPhone após o backup para liberar espaço.</dd>
<dt>Política de exclusão › Espelhar</dt>
<dd>Mantém a pasta do servidor como cópia exata da origem. Arquivos apagados no iPhone também são removidos do servidor.</dd>
<dt>Política de exclusão › Excluir arquivando</dt>
<dd>Arquivos removidos no iPhone são movidos para uma pasta datada <b>.backupflow_archive</b> no servidor em vez de serem apagados.</dd>
<dt>Soma de verificação (Checksum)</dt>
<dd>Verifica se cada arquivo chegou intacto ao servidor após o envio (padrão <b>Desativado</b> para velocidade máxima).</dd>
</dl>
<p class="note"><b>Dica para Fotos do iCloud:</b> Ative <b>Baixar itens do iCloud se necessário</b> para fazer backup também das fotos e vídeos originais armazenados apenas no iCloud.</p>""",
            ),
            (
                "background",
                "7. Backup em segundo plano",
                """<p>O BackupFlow usa o <b>BGTaskScheduler</b> do iOS para executar backups agendados em segundo plano. Como o iOS gerencia o momento exato de execução conforme a bateria e o uso do aparelho, a tarefa pode iniciar alguns minutos após o horário agendado ou enviar uma notificação.</p>
<p>Se o iOS pausar um backup, basta abrir o BackupFlow para continuar de onde parou, pulando os arquivos já enviados. Para o primeiro backup grande, mantenha o iPhone no Wi-Fi e conectado ao carregador.</p>""",
            ),
            (
                "history",
                "8. Histórico de Backup",
                """<p>Toque no botão central <b>Histórico (🕒)</b> na barra inferior da <b>Central de backup</b>:</p>
<ul>
<li><b>Cartões de resumo</b>: Veja o total de backups concluídos, falhas e o volume total transferido (GB/MB).</li>
<li><b>Registros detalhados</b>: Cada item mostra o nome da tarefa, data/hora, status, total de arquivos, tamanho e duração. Use o ícone de <b>lixeira (🗑️)</b> no canto superior direito para limpar o histórico.</li>
</ul>""",
            ),
            (
                "settings",
                "9. Configurações do aplicativo",
                """<p>Toque no ícone de <b>engrenagem (⚙️)</b> no canto superior direito da <b>Central de backup</b> para abrir as <b>Configurações</b>:</p>
<ul>
<li><b>Retenção de Histórico (Dias)</b>: Escolha por quantos dias o histórico é mantido (ex.: <b>30 dias</b>).</li>
<li><b>Requer Energia Externa</b> e <b>Configurações de Bateria</b>: Regras globais de carregamento e bateria mínima.</li>
<li><b>Idioma</b>: Altere o idioma do aplicativo instantaneamente entre os 12 idiomas suportados.</li>
<li><b>Sobre</b>: Veja a <b>Versão</b>, toque em <b>Avaliar App</b> ou em <b>Contatar Suporte</b>.</li>
<li><b>Redefinir Todos os Dados</b>: Remove todas as tarefas, histórico e senhas salvas deste iPhone sem afetar os arquivos nos seus servidores.</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. Solução de problemas",
                """<dl>
<dt>Não consigo conectar ao meu servidor.</dt>
<dd>Verifique endereço, porta (FTP 21, SFTP 22, WebDAV 443/80), usuário e senha. Em servidores domésticos, confirme que o iPhone está no mesmo Wi-Fi e que a permissão está ativa em <b>Ajustes do iPhone › Privacidade e Segurança › Rede Local › BackupFlow</b>.</dd>
<dt>Um backup agendado não rodou.</dt>
<dd>Verifique as condições em <b>Comportamento do backup</b> (Wi-Fi, energia, janela de horário, bateria) e as notificações do app.</dd>
<dt>Algumas fotos estão faltando.</dt>
<dd>Permita acesso total às Fotos e ative <b>Baixar itens do iCloud se necessário</b>.</dd>
<dt>Arquivos sumiram do servidor.</dt>
<dd>Altere a <b>Política de exclusão</b> da tarefa de <b>Espelhar</b> para <b>Somente adicionar</b> ou <b>Excluir arquivando</b>.</dd>
<dt>Aviso de segurança SFTP.</dt>
<dd>A impressão digital SSH do servidor mudou. Isso é esperado se o servidor foi reinstalado ou trocado; caso contrário, consulte o administrador.</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. Privacidade e segurança",
                """<p>Seus arquivos vão diretamente do iPhone para o seu próprio servidor. O BackupFlow não possui servidores intermediários, nunca vê seus arquivos e não coleta dados pessoais ou analíticos. As senhas são criptografadas nas <b>Chaves do iOS (Keychain)</b>. Leia nossa <a href="../../privacy-policy.html">Política de Privacidade</a> completa.</p>""",
            ),
            (
                "help",
                "12. Precisa de ajuda?",
                """<p>Vá em <b>Configurações › Contatar Suporte</b> no aplicativo (ou envie um e-mail para <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a>). A versão do app e o modelo do iPhone são adicionados automaticamente.</p>""",
            ),
        ],
    },

    "hi": {
        "title": "BackupFlow सहायता और दस्तावेज़ीकरण",
        "description": "iOS के लिए BackupFlow की पूरी गाइड: बैकअप हब, FTP/SFTP/WebDAV सेटअप, फ़ोटो लाइब्रेरी और फ़ाइल बैकअप, शेड्यूलिंग, हटाने की नीति और समस्या समाधान।",
        "h1": "BackupFlow सहायता",
        "lead": "BackupFlow आपके iPhone की फ़ोटो, वीडियो और फ़ाइलों का बैकअप FTP, SFTP या WebDAV के ज़रिए सीधे आपके अपने सर्वर (NAS, होम सर्वर या निजी क्लाउड) पर लेता है। न कोई सब्सक्रिप्शन, न कोई थर्ड-पार्टी क्लाउड।",
        "toc_title": "इस पेज पर",
        "sections": [
            (
                "what-you-need",
                "1. आपको क्या चाहिए",
                """<ul>
<li><b>एक संगत सर्वर</b>: कोई भी NAS (Synology, QNAP, TrueNAS, Unraid), होम सर्वर या निजी क्लाउड (Nextcloud, ownCloud, WebDAV) जो <b>FTP</b>, <b>SFTP (SSH)</b> या <b>WebDAV (HTTP/HTTPS)</b> सपोर्ट करता हो।</li>
<li><b>कनेक्शन विवरण</b>: सर्वर का पता, पोर्ट (डिफ़ॉल्ट: FTP <b>21</b>, SFTP <b>22</b>, WebDAV <b>443</b>/<b>80</b>), <b>उपयोगकर्ता नाम</b> और <b>पासवर्ड</b> (FTP के लिए अनाम लॉगिन भी उपलब्ध)।</li>
<li><b>iOS अनुमतियाँ</b>: <b>फ़ोटो</b> की पूर्ण अनुमति, होम सर्वर के लिए <b>लोकल नेटवर्क</b> अनुमति, और <b>नोटिफ़िकेशन</b>।</li>
</ul>""",
            ),
            (
                "backup-hub",
                "2. बैकअप हब का परिचय",
                """<p>BackupFlow खोलने पर <b>बैकअप हब</b> आपकी बैकअप प्रणाली की लाइव स्थिति दिखाता है:</p>
<ul>
<li><b>स्टेटस कार्ड</b>: पिछला सिंक समय, अगले टास्क का समय, सुरक्षा स्थिति, सर्वर पता और तुरंत बैकअप शुरू करने के लिए हरा <b>प्ले (▶)</b> बटन दिखाता है।</li>
<li><b>बैकअप स्वास्थ्य</b>: सफलता दर (प्रतिशत और कुल रन), लगातार विफलताएँ, पिछला सफल बैकअप और औसत समय दिखाता है।</li>
<li><b>सहेजे गए सर्वर</b>: आपके सभी <b>FTP</b>, <b>SFTP</b> और <b>WebDAV</b> टास्क के कार्ड, जिनमें त्वरित <b>संपादित करें (✏️)</b> और <b>हटाएँ (🗑️)</b> बटन शामिल हैं। किसी भी कार्ड पर टैप करके <b>टास्क विवरण</b> खोलें।</li>
<li><b>निचला बार और सेटिंग्स</b>: नीचे दिए गए तीन बटनों से <b>सिंक/रन (🔄)</b> करें, <b>बैकअप इतिहास (🕒)</b> खोलें या <b>नया बैकअप (+)</b> बनाएँ। ऊपर दाईं ओर <b>गियर आइकन (⚙️)</b> से <b>सेटिंग्स</b> खुलती हैं।</li>
</ul>""",
            ),
            (
                "first-backup",
                "3. नया बैकअप बनाएँ",
                """<p><b>बैकअप हब</b> के नीचे <b>+</b> बटन (या <b>सहेजे गए सर्वर</b> के पास <b>जोड़ें</b>) पर टैप करके <b>नया बैकअप</b> स्क्रीन खोलें:</p>
<ol>
<li><b>स्रोत</b>: <b>फ़ोटो लाइब्रेरी</b> (केवल फ़ोटो, केवल वीडियो, या दोनों) चुनें या iOS <b>Files</b> ऐप से कोई फ़ोल्डर चुनने के लिए <b>फ़ोल्डर चुनें</b> पर टैप करें।</li>
<li><b>लक्ष्य प्रकार</b>: <b>FTP</b>, <b>SFTP</b> या <b>WebDAV</b> चुनें। सर्वर पता, पोर्ट, <b>उपयोगकर्ता नाम</b>, <b>पासवर्ड</b> और रिमोट पथ (जैसे <code>/remote.php/dav/files/</code>) दर्ज करें। <b>कनेक्शन टेस्ट करें</b> पर टैप करें और चाहें तो <b>रिमोट फ़ोल्डर ब्राउज़ करें</b> से गंतव्य फ़ोल्डर चुनें।</li>
<li><b>शेड्यूलिंग</b>: <b>मैनुअल</b>, <b>दैनिक</b>, <b>साप्ताहिक</b>, <b>मासिक</b> या <b>अंतराल</b> चुनें और <b>समय चुनें</b> में समय सेट करें।</li>
<li><b>बैकअप व्यवहार</b>: <b>हटाने की नीति</b>, <b>चेकसम</b> और नेटवर्क/पावर शर्तें चुनें और टास्क सेव करें।</li>
</ol>
<p>पहले पूर्ण बैकअप के बाद, केवल नई या बदली हुई फ़ाइलें ही भेजी जाती हैं, जिससे अगले बैकअप बहुत तेज़ी से पूरे होते हैं।</p>""",
            ),
            (
                "task-details",
                "4. टास्क विवरण और प्रबंधन",
                """<p><b>सहेजे गए सर्वर</b> में किसी भी टास्क पर टैप करके <b>टास्क विवरण</b> देखें:</p>
<ul>
<li><b>सामान्य</b>: स्रोत, वर्तमान स्थिति, शेड्यूल, <b>हटाने की नीति</b> और <b>चेकसम</b> देखें।</li>
<li><b>सर्वर</b>: सर्वर का पता, पोर्ट और उपयोगकर्ता नाम देखें।</li>
<li><b>हाल के बैकअप</b>: इस टास्क के पिछले बैकअप रन का समय, स्थिति, फ़ाइलों की संख्या, आकार और अवधि देखें।</li>
<li>ऊपर बाईं ओर <b>संपादित करें</b> पर टैप करके टास्क में बदलाव करें।</li>
</ul>""",
            ),
            (
                "automatic-backups",
                "5. शेड्यूलिंग और शर्तें",
                """<p><b>शेड्यूलिंग</b> में आप <b>मैनुअल</b>, <b>दैनिक</b>, <b>साप्ताहिक</b>, <b>मासिक</b> या <b>अंतराल</b> चुन सकते हैं और <b>समय चुनें</b> में समय निर्धारित कर सकते हैं।</p>
<p><b>बैकअप व्यवहार</b> में आप तय कर सकते हैं कि ऑटोमैटिक बैकअप कब चले:</p>
<ul>
<li><b>Wi-Fi आवश्यक</b>: मोबाइल डेटा का उपयोग कभी नहीं करता।</li>
<li><b>बाहरी बिजली आवश्यक</b>: केवल तभी चलता है जब iPhone चार्ज हो रहा हो।</li>
<li><b>अनुमत समय विंडो उपयोग करें</b>: केवल चुने गए समय (जैसे रात में) के दौरान बैकअप चलाता है।</li>
<li><b>न्यूनतम बैटरी स्तर</b> (<b>सेटिंग्स › बैटरी सेटिंग्स</b> में): बैटरी कम होने पर बैकअप छोड़ देता है।</li>
</ul>""",
            ),
            (
                "deleted-files",
                "6. हटाने की नीति, चेकसम और iCloud",
                """<p><b>बैकअप व्यवहार</b> में चुनें कि iPhone पर फ़ाइलें डिलीट करने पर सर्वर पर क्या हो और फ़ाइल की जाँच कैसे हो:</p>
<dl>
<dt>हटाने की नीति › केवल जोड़ें</dt>
<dd>सर्वर से कभी कुछ डिलीट नहीं होता। यदि आप बैकअप के बाद iPhone में जगह खाली करने के लिए फ़ोटो डिलीट करना चाहते हैं, तो <b>इसी विकल्प को चुनें</b>।</dd>
<dt>हटाने की नीति › मिरर</dt>
<dd>सर्वर फ़ोल्डर को स्रोत की हूबहू कॉपी रखता है। iPhone से हटाई गई फ़ाइलें सर्वर से भी डिलीट हो जाती हैं।</dd>
<dt>हटाने की नीति › आर्काइव हटाना</dt>
<dd>हटाई गई फ़ाइलें डिलीट होने के बजाय सर्वर पर तारीख वाले <b>.backupflow_archive</b> फ़ोल्डर में चली जाती हैं।</dd>
<dt>चेकसम (Checksum)</dt>
<dd>अपलोड के बाद जाँचता है कि हर फ़ाइल सर्वर पर सही-सलामत पहुँची है (अधिकतम गति के लिए डिफ़ॉल्ट <b>बंद</b>)।</dd>
</dl>
<p class="note"><b>iCloud फ़ोटो टिप:</b> <b>आवश्यक होने पर iCloud आइटम डाउनलोड करें</b> चालू करें ताकि केवल iCloud में रखे गए मूल फ़ोटो और वीडियो का भी बैकअप लिया जा सके।</p>""",
            ),
            (
                "background",
                "7. बैकग्राउंड में बैकअप",
                """<p>BackupFlow शेड्यूल किए गए बैकअप चलाने के लिए iOS के <b>BGTaskScheduler</b> का उपयोग करता है। चूँकि iOS बैटरी और उपयोग के आधार पर बैकग्राउंड समय तय करता है, इसलिए बैकअप तय समय से कुछ देर बाद शुरू हो सकता है या नोटिफ़िकेशन भेज सकता है।</p>
<p>यदि iOS बीच में बैकअप रोक दे, तो ऐप खोलने पर यह वहीं से आगे बढ़ता है और पहले भेजी जा चुकी फ़ाइलों को छोड़ देता है। बड़े शुरुआती बैकअप के लिए iPhone को Wi-Fi और चार्जर से जोड़े रखें।</p>""",
            ),
            (
                "history",
                "8. बैकअप इतिहास",
                """<p><b>बैकअप हब</b> के निचले बार के बीच वाले <b>इतिहास (🕒)</b> बटन पर टैप करके <b>बैकअप इतिहास</b> खोलें:</p>
<ul>
<li><b>सारांश कार्ड</b>: ऊपर कुल पूर्ण, विफल और कुल ट्रांसफ़र किए गए डेटा (GB/MB) की जानकारी देखें।</li>
<li><b>विस्तृत लॉग</b>: हर कार्ड में टास्क का नाम, तारीख, स्थिति, फ़ाइल संख्या (जैसे <code>1236/1236</code>), आकार और समय दिखता है। ऊपर दाईं ओर <b>ट्रैश आइकन (🗑️)</b> से इतिहास साफ़ कर सकते हैं।</li>
</ul>""",
            ),
            (
                "settings",
                "9. ऐप सेटिंग्स",
                """<p><b>बैकअप हब</b> के ऊपर दाईं ओर <b>गियर आइकन (⚙️)</b> पर टैप करके <b>सेटिंग्स</b> खोलें:</p>
<ul>
<li><b>इतिहास अवधारण (दिन)</b>: इतिहास कितने दिनों तक रखा जाए चुनें (जैसे <b>30 दिन</b>)।</li>
<li><b>बाहरी बिजली आवश्यक</b> और <b>बैटरी सेटिंग्स</b>: पावर और न्यूनतम बैटरी नियम।</li>
<li><b>भाषा</b>: समर्थित 12 भाषाओं में से किसी भी भाषा में ऐप इंटरफ़ेस तुरंत बदलें।</li>
<li><b>के बारे में</b>: ऐप <b>वर्ज़न</b> देखें, <b>ऐप को रेट करें</b> या <b>सहायता से संपर्क करें</b> पर टैप करें।</li>
<li><b>सभी डेटा रीसेट करें</b>: इस iPhone से सभी टास्क, इतिहास और सहेजे गए पासवर्ड हटाता है। आपके सर्वर की फ़ाइलों को छुआ नहीं जाता।</li>
</ul>""",
            ),
            (
                "troubleshooting",
                "10. समस्या समाधान",
                """<dl>
<dt>सर्वर से कनेक्ट नहीं हो पा रहा है।</dt>
<dd>पता, पोर्ट (FTP 21, SFTP 22, WebDAV 443/80), उपयोगकर्ता नाम और पासवर्ड जाँचें। होम सर्वर के लिए सुनिश्चित करें कि iPhone उसी Wi-Fi पर है और <b>iPhone सेटिंग्स › गोपनीयता और सुरक्षा › लोकल नेटवर्क › BackupFlow</b> चालू है।</dd>
<dt>शेड्यूल किया गया बैकअप नहीं चला।</dt>
<dd><b>बैकअप व्यवहार</b> की शर्तें (Wi-Fi, बिजली, समय विंडो, बैटरी) और नोटिफ़िकेशन अनुमति जाँचें।</dd>
<dt>कुछ फ़ोटो गायब हैं।</dt>
<dd>फ़ोटो की पूर्ण अनुमति दें और <b>आवश्यक होने पर iCloud आइटम डाउनलोड करें</b> चालू करें।</dd>
<dt>सर्वर से फ़ाइलें हट गईं।</dt>
<dd>टास्क की <b>हटाने की नीति</b> को <b>मिरर</b> से बदलकर <b>केवल जोड़ें</b> या <b>आर्काइव हटाना</b> करें।</dd>
<dt>SFTP सुरक्षा चेतावनी दिख रही है।</dt>
<dd>सर्वर की SSH पहचान बदल गई है। सर्वर दोबारा इंस्टॉल होने पर यह सामान्य है; अन्यथा अपने सर्वर एडमिन से संपर्क करें।</dd>
</dl>""",
            ),
            (
                "privacy",
                "11. गोपनीयता और सुरक्षा",
                """<p>आपकी फ़ाइलें सीधे आपके iPhone से आपके सर्वर पर जाती हैं। BackupFlow का अपना कोई सर्वर नहीं है, यह आपकी फ़ाइलें कभी नहीं देखता और कोई डेटा इकट्ठा नहीं करता। पासवर्ड <b>iOS कीचेन (Keychain)</b> में सुरक्षित रूप से एन्क्रिप्टेड रहते हैं। पूरी जानकारी के लिए हमारी <a href="../../privacy-policy.html">गोपनीयता नीति</a> पढ़ें।</p>""",
            ),
            (
                "help",
                "12. मदद चाहिए?",
                """<p>ऐप में <b>सेटिंग्स › सहायता से संपर्क करें</b> पर जाएँ (या <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a> पर ईमेल करें)। ऐप वर्ज़न और डिवाइस मॉडल अपने-आप जुड़ जाते हैं।</p>""",
            ),
        ],
    },
}
