# -*- coding: utf-8 -*-
"""Localized Privacy Policy content (Part 2: ar, zh, ko, ja, pt, hi) for BackupFlow."""

PRIVACY_PART_2 = {
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
            (
                "introduction",
                "1. مقدمة",
                """<p>مرحبًا بك في BackupFlow. نحن ملتزمون بحماية خصوصيتك وأمن بياناتك. توضح سياسة الخصوصية هذه كيف يتعامل BackupFlow مع المعلومات عند استخدام تطبيقنا على iOS وموقعنا الإلكتروني.</p>
<p><b>المبدأ الأساسي:</b> يعمل BackupFlow ببنية محلية بالكامل. لا تُرفع صورك أو مقاطع الفيديو أو مستنداتك أو بيانات اعتماد الخادم إلى خوادمنا أو أي خدمة سحابية خارجية أبدًا. تتم جميع عمليات النقل مباشرة بين جهاز iPhone الخاص بك والخادم الذي تحدده (NAS أو خادم منزلي أو سحابة شخصية).</p>""",
            ),
            (
                "not-collected",
                "2. المعلومات التي لا نجمعها",
                """<p>لا يجمع BackupFlow أو يخزن أو يشارك <b>أيًا</b> مما يلي:</p>
<ul>
<li>صورك أو مقاطع الفيديو أو البيانات الوصفية للوسائط</li>
<li>الملفات أو المجلدات المختارة من تطبيق الملفات في iOS</li>
<li>عناوين خوادمك أو المنافذ أو أسماء المستخدمين أو كلمات المرور</li>
<li>مهام النسخ الاحتياطي أو الجداول الزمنية أو سجل النسخ</li>
<li>معرّفات الجهاز أو معرّفات الإعلانات (IDFA) أو تحليلات الاستخدام</li>
<li>عنوان IP الخاص بك أو موقعك الجغرافي أو جهات اتصالك</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. كيف تبقى بياناتك خاصة",
                """<h3>3.1 التخزين المحلي وسلسلة مفاتيح iOS (Keychain)</h3>
<p>تُحفظ جميع إعدادات المهام والجداول والسجلات محليًا على جهاز iPhone الخاص بك. وتُشفّر كلمات مرور الخوادم (FTP وSFTP وWebDAV) داخل <b>سلسلة مفاتيح iOS (Keychain)</b> ولا تغادر جهازك أبدًا إلا عند المصادقة المباشرة مع خادمك.</p>
<h3>3.2 النقل المباشر إلى الخادم</h3>
<p>عند تشغيل النسخ الاحتياطي، تنتقل ملفاتك مباشرة من iPhone إلى خادمك عبر <b>FTP</b> أو <b>SFTP (SSH)</b> أو <b>WebDAV (HTTP/HTTPS)</b> دون أي خوادم وسيطة.</p>
<h3>3.3 لا تحليلات أو تتبع من طرف ثالث</h3>
<p>لا يحتوي BackupFlow على أي أدوات تحليل أو تتبع أو شبكات إعلانية خارجية.</p>""",
            ),
            (
                "app-store-info",
                "4. معلومات App Store والنظام",
                """<p>البيانات الخارجية الوحيدة هي المعلومات القياسية التي تعالجها شركة Apple عبر App Store (تأكيد الشراء، وتقارير الأعطال الاختيارية المجهولة عبر إعدادات iOS، والمراجعات العامة في المتجر)، وهي تخضع لسياسة خصوصية Apple.</p>""",
            ),
            (
                "permissions",
                "5. الأذونات والوصول إلى الجهاز",
                """<ul>
<li><b>مكتبة الصور</b>: تُستخدم فقط لقراءة الصور ومقاطع الفيديو ونسخها احتياطيًا إلى خادمك (بما في ذلك تنزيل النسخ الأصلية من iCloud عند التفعيل).</li>
<li><b>الملفات والمجلدات</b>: عند اختيار <b>اختر مجلد</b>، يصل التطبيق فقط إلى المجلد الذي حددته في تطبيق الملفات.</li>
<li><b>الشبكة المحلية والإنترنت</b>: تُستخدم حصريًا للاتصال بخادم FTP أو SFTP أو WebDAV الخاص بك.</li>
<li><b>التحديث في الخلفية والإشعارات</b>: تُستخدم فقط لتشغيل النسخ المجدولة (<code>BGTaskScheduler</code>) وإبلاغك بحالتها.</li>
</ul>""",
            ),
            (
                "security",
                "6. أمان البيانات وسلامتها",
                """<ul>
<li><b>بروتوكولات مشفرة</b>: دعم النقل المشفر عبر <b>SFTP (SSH)</b> و<b>WebDAV عبر HTTPS</b>.</li>
<li><b>التحقق من هوية خادم SFTP</b>: يتذكر بصمة SSH لخادمك عند أول اتصال وينبّهك إذا تغيّرت.</li>
<li><b>المجموع الاختباري (Checksum)</b>: خيار للتحقق من سلامة الملفات بعد رفعها.</li>
<li><b>حماية Keychain</b>: تشفير كلمات المرور داخل سلسلة مفاتيح iOS.</li>
</ul>""",
            ),
            (
                "third-party",
                "7. خدمات الطرف الثالث",
                """<p>لا يتكامل BackupFlow مع أي خدمات خارجية لجمع البيانات أو الإعلانات، ويتصل فقط بالخوادم التي تقوم بإعدادها.</p>""",
            ),
            (
                "children",
                "8. خصوصية الأطفال",
                """<p>لا يجمع BackupFlow أي بيانات شخصية من أي شخص، بما في ذلك الأطفال دون سن 13 عامًا.</p>""",
            ),
            (
                "your-rights",
                "9. حقوقك والتحكم وإعادة تعيين البيانات",
                """<p>تحتفظ بالتحكم الكامل على جهازك:</p>
<ul>
<li>يمكنك تعديل أو حذف المهام والخوادم في أي وقت من <b>مركز النسخ الاحتياطي</b>.</li>
<li>يمكنك مسح السجل من <b>سجل النسخ الاحتياطي</b> أو تعديل مدة الحفظ في <b>الإعدادات › الاحتفاظ بالسجل (أيام)</b>.</li>
<li>يمكنك مسح جميع المهام والسجلات وكلمات المرور المحفوظة من جهازك فورًا عبر <b>الإعدادات › إعادة تعيين جميع البيانات</b> أو بحذف التطبيق، دون المساس بالملفات الموجودة على خوادمك.</li>
</ul>""",
            ),
            (
                "changes",
                "10. التغييرات على سياسة الخصوصية",
                """<p>قد نحدّث هذه السياسة من وقت لآخر، وسيتم نشر أي تحديث في هذه الصفحة مع تاريخ التحديث الجديد.</p>""",
            ),
            (
                "contact",
                "11. معلومات التواصل",
                """<p>لأي استفسار حول الخصوصية، تواصل معنا عبر <b>الإعدادات › اتصل بالدعم</b> داخل التطبيق أو عبر البريد الإلكتروني:</p>
<ul>
<li><b>البريد الإلكتروني</b>: <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>المطوّر</b>: Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. الامتثال القانوني (GDPR / CCPA)",
                """<p>يلتزم BackupFlow باللائحة العامة لحماية البيانات (<b>GDPR</b>) وقانون <b>CCPA</b> وقوانين الخصوصية الدولية بفضل تصميمه الذي لا يجمع أي بيانات شخصية.</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. 引言",
                """<p>欢迎使用 BackupFlow。我们致力于保护您的隐私和数据安全。本隐私政策说明了当您使用我们的 iOS 应用和网站时，BackupFlow 如何处理信息。</p>
<p><b>核心原则：</b>BackupFlow 采用严格的<b>本地优先、零知识架构</b>。您的照片、视频、文档和服务器凭据绝不会上传至我们的服务器或任何第三方云服务。所有传输均在您的 iPhone 与您自己配置的服务器（NAS、家庭服务器或私有云）之间直接进行。</p>""",
            ),
            (
                "not-collected",
                "2. 我们不收集的信息",
                """<p>BackupFlow <b>不会</b>收集、传输、存储或出售以下任何信息：</p>
<ul>
<li>您的照片、视频或媒体元数据</li>
<li>从 iOS“文件”应用中选择的文件夹或文件</li>
<li>您的服务器地址、端口、用户名或密码</li>
<li>您的备份任务、日程安排或备份历史记录</li>
<li>设备标识符、广告标识符 (IDFA) 或使用情况分析</li>
<li>您的 IP 地址、地理位置或通讯录</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. 您的数据如何保持私密",
                """<h3>3.1 本地存储与 iOS 钥匙串 (Keychain)</h3>
<p>所有备份任务配置、计划、历史记录和应用设置均仅保存在您的 iPhone 本地。服务器凭据（FTP、SFTP 和 WebDAV 密码）加密存储在硬件级保护的 <b>iOS 钥匙串 (Keychain)</b> 中，除直接向您自己的服务器认证外，绝不会离开您的设备。</p>
<h3>3.2 设备到服务器直接传输</h3>
<p>执行备份时，您的文件通过标准协议（<b>FTP</b>、<b>SFTP/SSH</b> 或 <b>HTTP/HTTPS WebDAV</b>）直接从 iPhone 传输到您指定的服务器，不经过任何中转服务器。</p>
<h3>3.3 零第三方分析或跟踪</h3>
<p>BackupFlow 不包含任何第三方统计分析 SDK、遥测跟踪器或广告框架。</p>""",
            ),
            (
                "app-store-info",
                "4. App Store 与系统信息",
                """<p>与应用关联的唯一外部信息是由 Apple 通过 App Store 按标准处理的数据（购买验证、您在 iOS 设置中选择共享的匿名崩溃诊断日志，以及您在 App Store 公开发布的评分与评价），这些信息受 Apple 隐私政策约束。</p>""",
            ),
            (
                "permissions",
                "5. 权限与设备访问",
                """<ul>
<li><b>照片图库访问权限</b>：仅用于读取照片和视频并备份到您的服务器（包括在开启<i>需要时下载 iCloud 项目</i>时下载 iCloud 原片）。</li>
<li><b>文件与文件夹访问权限</b>：当您轻点<b>选择文件夹</b>时，BackupFlow 仅通过 iOS 安全书签读取您在“文件”应用中选择的文件夹。</li>
<li><b>本地网络与互联网访问权限</b>：仅用于连接您配置的 FTP、SFTP 或 WebDAV 服务器。</li>
<li><b>后台应用刷新与通知</b>：仅用于通过 <code>BGTaskScheduler</code> 执行计划备份并通知您备份状态。</li>
</ul>""",
            ),
            (
                "security",
                "6. 数据安全与完整性",
                """<ul>
<li><b>加密传输协议</b>：支持通过 <b>SFTP (SSH)</b> 和 <b>HTTPS WebDAV</b> 进行加密传输。</li>
<li><b>SFTP 主机密钥验证</b>：首次连接时记住服务器的 SSH 指纹，若服务器身份发生变化会立即向您发出警告。</li>
<li><b>校验和验证 (Checksum)</b>：可选的<b>校验和</b>功能可在上传后验证服务器上的文件完整性。</li>
<li><b>钥匙串保护</b>：密码受 iOS 钥匙串硬件加密保护。</li>
</ul>""",
            ),
            (
                "third-party",
                "7. 第三方服务",
                """<p>BackupFlow 不集成任何用于数据收集、分析或广告的第三方服务，应用仅与您明确配置的备份服务器通信。</p>""",
            ),
            (
                "children",
                "8. 儿童隐私",
                """<p>BackupFlow 不会收集任何人的个人信息，包括 13 岁以下的儿童。</p>""",
            ),
            (
                "your-rights",
                "9. 您的权利、控制与重置所有数据",
                """<p>您在 iPhone 上拥有对数据的完全控制权：</p>
<ul>
<li>随时在<b>备份中心</b>中查看、编辑或删除备份任务和已保存的服务器。</li>
<li>随时在<b>备份历史</b>中清空记录，或在<b>设置 › 历史记录保留期（天）</b>中调整保留天数。</li>
<li>随时轻点<b>设置 › 重置所有数据</b>（或卸载应用）以永久清除设备上的所有任务、历史记录和已保存的钥匙串密码。您服务器上已备份的文件不会受到任何影响。</li>
</ul>""",
            ),
            (
                "changes",
                "10. 隐私政策的变更",
                """<p>我们可能会不时更新本隐私政策，任何变更都将在此页面发布并更新“最后更新”日期。</p>""",
            ),
            (
                "contact",
                "11. 联系方式",
                """<p>如对本隐私政策有任何疑问，您可以通过应用内的<b>设置 › 联系支持</b>或以下方式联系我们：</p>
<ul>
<li><b>电子邮件</b>：<a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>开发者</b>：Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. 适用法律与合规性 (GDPR / CCPA)",
                """<p>BackupFlow 遵循欧盟《通用数据保护条例》(<b>GDPR</b>)、加州消费者隐私法案 (<b>CCPA</b>) 及全球主要隐私法规的“默认隐私保护 (Privacy by Design)”原则。</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. 개요",
                """<p>BackupFlow에 오신 것을 환영합니다. 당사는 사용자의 개인정보와 데이터 보안을 철저히 보호합니다. 본 개인정보 처리방침은 iOS 앱과 웹사이트 이용 시 정보가 어떻게 처리되는지 설명합니다.</p>
<p><b>핵심 원칙:</b> BackupFlow는 철저한 <b>로컬 우선(Local-First) 아키텍처</b>로 작동합니다. 사진, 동영상, 문서 및 서버 로그인 정보는 당사 서버나 제3자 클라우드에 업로드되지 않으며, iPhone과 사용자가 지정한 서버(NAS, 홈 서버, 개인 클라우드) 간에 직접 전송됩니다.</p>""",
            ),
            (
                "not-collected",
                "2. 수집하지 않는 정보",
                """<p>BackupFlow는 다음 정보를 <b>절대 수집, 저장, 전송 또는 판매하지 않습니다</b>:</p>
<ul>
<li>사진, 동영상 및 미디어 메타데이터</li>
<li>iOS 파일 앱에서 선택한 파일 및 폴더</li>
<li>서버 주소, 포트, 사용자 이름 및 비밀번호</li>
<li>백업 작업, 스케줄 설정 및 백업 기록</li>
<li>기기 식별자, 광고 ID(IDFA) 및 사용 분석 데이터</li>
<li>IP 주소, 위치 정보 및 연락처</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. 데이터 보호 방식",
                """<h3>3.1 로컬 저장소 및 iOS 키체인(Keychain)</h3>
<p>모든 백업 작업, 스케줄, 기록 및 앱 설정은 iPhone 내부에만 저장됩니다. 서버 비밀번호(FTP, SFTP, WebDAV)는 하드웨어 암호화가 적용된 <b>iOS 키체인(Keychain)</b>에 안전하게 저장되며, 사용자의 서버에 직접 로그인할 때를 제외하고 기기 외부로 나가지 않습니다.</p>
<h3>3.2 기기-서버 간 직접 전송</h3>
<p>백업 실행 시 모든 파일은 중간 서버 없이 <b>FTP</b>, <b>SFTP(SSH)</b> 또는 <b>WebDAV(HTTP/HTTPS)</b> 프로토콜을 통해 iPhone에서 사용자의 서버로 직접 전송됩니다.</p>
<h3>3.3 타사 분석 및 추적 없음</h3>
<p>BackupFlow에는 타사 분석 SDK, 원격 측정 추적기 또는 광고 프레임워크가 포함되어 있지 않습니다.</p>""",
            ),
            (
                "app-store-info",
                "4. App Store 및 시스템 정보",
                """<p>앱과 관련된 유일한 외부 데이터는 Apple이 App Store를 통해 처리하는 표준 정보(구매 확인, iOS 설정에서 공유에 동의한 익명 충돌 로그, 공개 App Store 리뷰)뿐이며, 이는 Apple의 개인정보 처리방침에 따라 관리됩니다.</p>""",
            ),
            (
                "permissions",
                "5. 권한 및 기기 접근",
                """<ul>
<li><b>사진 보관함 접근</b>: 사진과 동영상을 읽어 서버로 백업(및 <i>필요한 경우 iCloud 항목 다운로드</i> 활성화 시 iCloud 원본 다운로드)하기 위해서만 사용됩니다.</li>
<li><b>파일 및 폴더 접근</b>: <b>폴더 선택</b> 시 iOS 보안 북마크를 통해 사용자가 선택한 폴더만 읽습니다.</li>
<li><b>로컬 네트워크 및 인터넷 접근</b>: 설정한 FTP, SFTP 또는 WebDAV 서버에 연결하기 위해서만 사용됩니다.</li>
<li><b>백그라운드 앱 새로 고침 및 알림</b>: 예약된 백업 실행(<code>BGTaskScheduler</code>) 및 백업 상태 알림에만 사용됩니다.</li>
</ul>""",
            ),
            (
                "security",
                "6. 데이터 보안 및 무결성",
                """<ul>
<li><b>암호화 전송</b>: <b>SFTP(SSH)</b> 및 <b>HTTPS 기반 WebDAV</b> 암호화 전송을 지원합니다.</li>
<li><b>SFTP 호스트 키 확인</b>: 첫 연결 시 서버의 SSH 지문을 기억하고 변경 시 경고합니다.</li>
<li><b>체크섬(Checksum) 확인</b>: 업로드된 파일이 손상 없이 도착했는지 확인하는 체크섬 옵션을 제공합니다.</li>
<li><b>키체인 보호</b>: iOS 키체인을 통한 비밀번호 암호화 저장.</li>
</ul>""",
            ),
            (
                "third-party",
                "7. 제3자 서비스",
                """<p>BackupFlow는 데이터 수집, 분석 또는 광고를 위한 어떠한 제3자 서비스와도 연동하지 않으며 사용자가 설정한 백업 서버와만 통신합니다.</p>""",
            ),
            (
                "children",
                "8. 아동의 개인정보 보호",
                """<p>BackupFlow는 만 13세 미만 아동을 포함해 누구로부터도 개인정보를 수집하지 않습니다.</p>""",
            ),
            (
                "your-rights",
                "9. 사용자의 권리, 제어 및 데이터 초기화",
                """<p>사용자는 iPhone에서 모든 데이터를 직접 제어할 수 있습니다:</p>
<ul>
<li><b>백업 허브</b>에서 언제든지 작업과 저장된 서버를 편집하거나 삭제할 수 있습니다.</li>
<li><b>백업 기록</b>에서 기록을 지우거나 <b>설정 › 기록 보관 기간(일)</b>에서 보관 기간을 조정할 수 있습니다.</li>
<li><b>설정 › 모든 데이터 초기화</b>를 탭하거나 앱을 삭제하여 기기의 모든 작업, 기록 및 저장된 비밀번호를 즉시 삭제할 수 있습니다(서버의 파일은 유지됨).</li>
</ul>""",
            ),
            (
                "changes",
                "10. 개인정보 처리방침 변경",
                """<p>본 방침이 업데이트될 경우 변경된 최종 업데이트 날짜와 함께 이 페이지에 게시됩니다.</p>""",
            ),
            (
                "contact",
                "11. 문의처",
                """<p>문의 사항이 있으시면 앱 내 <b>설정 › 지원 문의</b> 또는 아래 이메일로 연락해 주세요:</p>
<ul>
<li><b>이메일</b>: <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>개발자</b>: Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. 법적 준수 (GDPR / CCPA)",
                """<p>BackupFlow는 개인정보를 수집하지 않는 설계(Privacy by Design)를 통해 <b>GDPR</b>, <b>CCPA</b> 및 각국의 개인정보 보호 법규를 준수합니다.</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. はじめに",
                """<p>BackupFlowへようこそ。私たちはお客様のプライバシーとデータの安全性を守ることをお約束します。本プライバシーポリシーでは、iOSアプリおよびウェブサイトをご利用いただく際の情報の取り扱いについて説明します。</p>
<p><b>基本原則：</b>BackupFlowは完全な<b>ローカルファースト・ゼロ知識アーキテクチャ</b>で動作します。写真、ビデオ、書類、サーバー認証情報が当社のサーバーや第三者のクラウドサービスにアップロードされることはありません。すべての転送はお使いのiPhoneとご自身で設定したサーバー（NAS、自宅サーバー、プライベートクラウド）の間で直接行われます。</p>""",
            ),
            (
                "not-collected",
                "2. 当社が収集しない情報",
                """<p>BackupFlowは以下の情報を<b>一切収集、保存、送信、販売しません</b>：</p>
<ul>
<li>写真、ビデオ、およびメディアのメタデータ</li>
<li>iOSの「ファイル」アプリから選択されたファイルやフォルダ</li>
<li>サーバーのアドレス、ポート番号、ユーザー名、パスワード</li>
<li>バックアップタスク、スケジュール、バックアップ履歴</li>
<li>デバイス識別子、広告識別子（IDFA）、利用状況の分析データ</li>
<li>IPアドレス、位置情報、連絡先</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. データのプライバシーが守られる仕組み",
                """<h3>3.1 ローカル保存とiOSキーチェーン（Keychain）</h3>
<p>すべてのタスク設定、スケジュール、履歴、アプリ設定はiPhone内にのみローカル保存されます。サーバーのパスワード（FTP、SFTP、WebDAV）はハードウェア暗号化された<b>iOSキーチェーン（Keychain）</b>に保存され、ご自身のサーバーへ直接認証する際を除きデバイス外へ出ることはありません。</p>
<h3>3.2 サーバーへの直接転送</h3>
<p>バックアップ実行時、ファイルは中継サーバーを介さず、<b>FTP</b>、<b>SFTP（SSH）</b>、または<b>WebDAV（HTTP/HTTPS）</b>でご自身のサーバーへ直接転送されます。</p>
<h3>3.3 第三者の分析・追跡ツールなし</h3>
<p>BackupFlowにはサードパーティ製の分析SDK、トラッキングツール、広告フレームワークは一切含まれていません。</p>""",
            ),
            (
                "app-store-info",
                "4. App Storeおよびシステム情報",
                """<p>本アプリに関連する唯一の外部情報は、AppleがApp Storeを通じて標準的に処理する情報（購入確認、iOS設定で共有を許可した場合の匿名クラッシュログ、公開レビュー）のみであり、Appleのプライバシーポリシーに従って管理されます。</p>""",
            ),
            (
                "permissions",
                "5. 権限とデバイスへのアクセス",
                """<ul>
<li><b>写真ライブラリへのアクセス</b>：写真やビデオを読み取り、サーバーへバックアップするため（および<i>必要に応じてiCloud項目をダウンロード</i>が有効な場合にiCloudからオリジナルを取得するため）だけに使用されます。</li>
<li><b>ファイルとフォルダへのアクセス</b>：<b>フォルダを選択</b>を使用際、「ファイル」アプリで選択されたフォルダのみを読み取ります。</li>
<li><b>ローカルネットワークとインターネット</b>：設定されたFTP、SFTP、WebDAVサーバーへの接続にのみ使用されます。</li>
<li><b>バックグラウンド更新と通知</b>：スケジュールされたバックアップの実行（<code>BGTaskScheduler</code>）と完了・エラー通知にのみ使用されます。</li>
</ul>""",
            ),
            (
                "security",
                "6. データの 보안と整合性",
                """<ul>
<li><b>暗号化通信</b>：<b>SFTP（SSH）</b>および<b>HTTPS WebDAV</b>による暗号化転送をサポートしています。</li>
<li><b>SFTPホスト鍵の検証</b>：初回接続時にサーバーのSSHフィンガープリントを記憶し、変更があった場合は警告します。</li>
<li><b>チェックサム検証（Checksum）</b>：アップロード後にファイルの整合性を検証するオプションを備えています。</li>
<li><b>キーチェーン保護</b>：iOSキーチェーンによるパスワードの安全な暗号化保管。</li>
</ul>""",
            ),
            (
                "third-party",
                "7. 第三者サービス",
                """<p>BackupFlowはデータ収集、分析、広告のための第三者サービスとは一切連携せず、お客様が設定したサーバーとのみ通信します。</p>""",
            ),
            (
                "children",
                "8. お子様のプライバシー",
                """<p>BackupFlowは13歳未満のお子様を含め、いかなる利用者からも個人情報を収集しません。</p>""",
            ),
            (
                "your-rights",
                "9. お客様の権利・管理・データのリセット",
                """<p>すべてのデータはお使いのiPhone上で完全に管理できます：</p>
<ul>
<li><b>バックアップハブ</b>からいつでもタスクや保存済みサーバーを編集・削除できます。</li>
<li><b>バックアップ履歴</b>から履歴を消去したり、<b>設定 › 履歴保持期間（日）</b>で保存日数を変更したりできます。</li>
<li><b>設定 › すべてのデータをリセット</b>をタップ（またはアプリをアンインストール）すると、すべてのタスク、履歴、保存済みパスワードをデバイスから即座に削除できます。サーバー上のファイルには影響しません。</li>
</ul>""",
            ),
            (
                "changes",
                "10. プライバシーポリシーの変更",
                """<p>本ポリシーを更新した場合は、改訂日とともに本ページに掲載します。</p>""",
            ),
            (
                "contact",
                "11. お問い合わせ先",
                """<p>ご質問がある場合は、アプリ内の<b>設定 › サポートに連絡</b>またはメールにてお問い合わせください：</p>
<ul>
<li><b>メール</b>：<a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>開発者</b>：Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. 法令遵守（GDPR / CCPA）",
                """<p>BackupFlowは個人データを収集しない設計（Privacy by Design）により、<b>GDPR</b>、<b>CCPA</b>および各国のプライバシー法規に準拠しています。</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. Introdução",
                """<p>Bem-vindo ao BackupFlow. Estamos comprometidos em proteger sua privacidade e garantir a segurança dos seus dados. Esta Política de Privacidade explica como o BackupFlow lida com informações quando você usa nosso aplicativo para iOS e nosso site.</p>
<p><b>Princípio Fundamental:</b> O BackupFlow opera com uma arquitetura estritamente local. Suas fotos, vídeos, documentos e credenciais de servidor nunca são enviados para nossos servidores ou serviços de nuvem de terceiros. Todas as transferências ocorrem diretamente entre o seu iPhone e o servidor configurado por você (NAS, servidor doméstico ou nuvem pessoal).</p>""",
            ),
            (
                "not-collected",
                "2. Informações que NÃO Coletamos",
                """<p>O BackupFlow <b>não</b> coleta, armazena, transmite ou vende nenhum dos seguintes dados:</p>
<ul>
<li>Suas fotos, vídeos ou metadados de mídia</li>
<li>Arquivos ou pastas selecionados no app Arquivos do iOS</li>
<li>Endereços de servidores, portas, nomes de usuário ou senhas</li>
<li>Suas tarefas de backup, agendamentos ou histórico de backups</li>
<li>Identificadores do dispositivo, IDs de publicidade (IDFA) ou análises de uso</li>
<li>Seu endereço IP, localização ou contatos</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. Como Seus Dados Permanecem Privados",
                """<h3>3.1 Armazenamento Local e Chaves do iOS (Keychain)</h3>
<p>Todas as configurações de tarefas, agendamentos, histórico e preferências ficam armazenados localmente no seu iPhone. As senhas dos seus servidores (FTP, SFTP e WebDAV) são criptografadas nas <b>Chaves do iOS (Keychain)</b> e nunca saem do aparelho, exceto para autenticar diretamente no seu servidor.</p>
<h3>3.2 Transferência Direta para o Servidor</h3>
<p>Durante o backup, seus arquivos são transferidos diretamente do iPhone para o seu servidor usando <b>FTP</b>, <b>SFTP (SSH)</b> ou <b>WebDAV (HTTP/HTTPS)</b>, sem servidores intermediários.</p>
<h3>3.3 Sem Análises ou Rastreadores de Terceiros</h3>
<p>O BackupFlow não inclui SDKs de análise, rastreamento ou publicidade de terceiros.</p>""",
            ),
            (
                "app-store-info",
                "4. Informações da App Store e do Sistema",
                """<p>As únicas informações externas são os dados padrão processados pela Apple na App Store (confirmação de compra, relatórios opcionais e anônimos de falhas do iOS e avaliações públicas na App Store), regidos pela política de privacidade da Apple.</p>""",
            ),
            (
                "permissions",
                "5. Permissões e Acesso ao Dispositivo",
                """<ul>
<li><b>Biblioteca de Fotos</b>: Usada exclusivamente para ler e fazer backup de suas fotos e vídeos no seu servidor (incluindo o download opcional de originais do iCloud).</li>
<li><b>Arquivos e Pastas</b>: Ao tocar em <b>Selecionar pasta</b>, o BackupFlow acessa apenas a pasta escolhida no app Arquivos.</li>
<li><b>Rede Local e Internet</b>: Usadas exclusivamente para conectar ao seu servidor FTP, SFTP ou WebDAV.</li>
<li><b>Atualização em Segundo Plano e Notificações</b>: Usadas apenas para executar backups agendados (<code>BGTaskScheduler</code>) e informar o status das tarefas.</li>
</ul>""",
            ),
            (
                "security",
                "6. Segurança e Integridade dos Dados",
                """<ul>
<li><b>Protocolos Criptografados</b>: Suporte a transferências seguras via <b>SFTP (SSH)</b> e <b>WebDAV sobre HTTPS</b>.</li>
<li><b>Verificação de Chave SFTP</b>: Memoriza a impressão digital SSH do servidor na primeira conexão e alerta caso ela mude.</li>
<li><b>Soma de Verificação (Checksum)</b>: Verificação opcional de integridade dos arquivos enviados.</li>
<li><b>Proteção no Keychain</b>: Senhas protegidas por criptografia de hardware nas Chaves do iOS.</li>
</ul>""",
            ),
            (
                "third-party",
                "7. Serviços de Terceiros",
                """<p>O BackupFlow não se integra a nenhum serviço de terceiros para coleta de dados, análise ou publicidade, comunicando-se apenas com os servidores que você configura.</p>""",
            ),
            (
                "children",
                "8. Privacidade Infantil",
                """<p>O BackupFlow não coleta dados pessoais de ninguém, incluindo crianças menores de 13 anos.</p>""",
            ),
            (
                "your-rights",
                "9. Seus Direitos, Controle e Redefinição de Dados",
                """<p>Você mantém controle total diretamente no seu iPhone:</p>
<ul>
<li>Edite ou exclua tarefas e servidores a qualquer momento na <b>Central de backup</b>.</li>
<li>Limpe os registros no <b>Histórico de Backup</b> ou ajuste o prazo em <b>Configurações › Retenção de Histórico (Dias)</b>.</li>
<li>Apague todas as tarefas, histórico e senhas salvas deste dispositivo a qualquer momento tocando em <b>Configurações › Redefinir Todos os Dados</b> ou desinstalando o app. Os arquivos nos seus servidores nunca são afetados.</li>
</ul>""",
            ),
            (
                "changes",
                "10. Alterações nesta Política de Privacidade",
                """<p>Eventuais atualizações desta política serão publicadas nesta página com a data de revisão atualizada.</p>""",
            ),
            (
                "contact",
                "11. Informações de Contato",
                """<p>Em caso de dúvidas, entre em contato por <b>Configurações › Contatar Suporte</b> no app ou pelo e-mail:</p>
<ul>
<li><b>E-mail</b>: <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>Desenvolvedor</b>: Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. Jurisdição e Conformidade (GDPR / LGPD / CCPA)",
                """<p>O BackupFlow está em conformidade com o <b>GDPR</b> (União Europeia), a <b>LGPD</b> (Brasil), o <b>CCPA</b> (Califórnia) e demais legislações internacionais de proteção de dados por não coletar dados pessoais.</p>""",
            ),
        ],
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
            (
                "introduction",
                "1. परिचय",
                """<p>BackupFlow में आपका स्वागत है। हम आपकी गोपनीयता और डेटा सुरक्षा के लिए प्रतिबद्ध हैं। यह गोपनीयता नीति बताती है कि जब आप हमारे iOS ऐप और वेबसाइट का उपयोग करते हैं तो BackupFlow जानकारी को कैसे संभालता है।</p>
<p><b>मुख्य सिद्धांत:</b> BackupFlow पूरी तरह से <b>लोकल-फ़र्स्ट आर्किटेक्चर</b> पर काम करता है। आपकी फ़ोटो, वीडियो, दस्तावेज़ और सर्वर क्रेडेंशियल कभी भी हमारे सर्वर या किसी तीसरे पक्ष की क्लाउड सेवा पर अपलोड नहीं किए जाते हैं। सभी ट्रांसफ़र सीधे आपके iPhone और आपके द्वारा सेट किए गए सर्वर (NAS, होम सर्वर या निजी क्लाउड) के बीच होते हैं।</p>""",
            ),
            (
                "not-collected",
                "2. जानकारी जो हम एकत्र नहीं करते",
                """<p>BackupFlow निम्नलिखित में से कोई भी डेटा <b>एकत्र, संग्रहीत या साझा नहीं करता है</b>:</p>
<ul>
<li>आपकी फ़ोटो, वीडियो या मीडिया मेटाडेटा</li>
<li>iOS Files ऐप से चुनी गई फ़ाइलें या फ़ोल्डर</li>
<li>आपके सर्वर का पता, पोर्ट, उपयोगकर्ता नाम या पासवर्ड</li>
<li>आपके बैकअप टास्क, शेड्यूल या बैकअप इतिहास</li>
<li>डिवाइस आईडी, विज्ञापन आईडी (IDFA) या उपयोग एनालिटिक्स</li>
<li>आपका IP पता, लोकेशन या कॉन्टैक्ट्स</li>
</ul>""",
            ),
            (
                "how-data-stays-private",
                "3. आपका डेटा कैसे सुरक्षित रहता है",
                """<h3>3.1 लोकल स्टोरेज और iOS कीचेन (Keychain)</h3>
<p>सभी बैकअप टास्क, शेड्यूल, इतिहास और ऐप सेटिंग्स आपके iPhone पर लोकल रूप से सहेजी जाती हैं। सर्वर पासवर्ड (FTP, SFTP और WebDAV) <b>iOS कीचेन (Keychain)</b> में एन्क्रिप्टेड रहते हैं और आपके सर्वर से सीधे कनेक्ट होने के अलावा कभी आपके डिवाइस से बाहर नहीं जाते।</p>
<h3>3.2 सीधे सर्वर पर ट्रांसफ़र</h3>
<p>बैकअप चलते समय आपकी फ़ाइलें बिना किसी बिचौलिए सर्वर के <b>FTP</b>, <b>SFTP (SSH)</b> या <b>WebDAV (HTTP/HTTPS)</b> के माध्यम से सीधे आपके सर्वर पर भेजी जाती हैं।</p>
<h3>3.3 कोई थर्ड-पार्टी एनालिटिक्स या ट्रैकिंग नहीं</h3>
<p>BackupFlow में कोई थर्ड-पार्टी एनालिटिक्स SDK, ट्रैकर या विज्ञापन नेटवर्क शामिल नहीं है।</p>""",
            ),
            (
                "app-store-info",
                "4. App Store और सिस्टम जानकारी",
                """<p>ऐप से जुड़ी एकमात्र बाहरी जानकारी Apple द्वारा App Store के माध्यम से प्रबंधित मानक जानकारी (खरीद सत्यापन, वैकल्पिक अनाम क्रैश रिपोर्ट और सार्वजनिक App Store समीक्षाएं) है, जो Apple की गोपनीयता नीति के अधीन है।</p>""",
            ),
            (
                "permissions",
                "5. अनुमतियाँ और डिवाइस एक्सेस",
                """<ul>
<li><b>फ़ोटो लाइब्रेरी एक्सेस</b>: केवल आपकी फ़ोटो और वीडियो को पढ़कर आपके सर्वर पर बैकअप लेने (और विकल्प चालू होने पर iCloud से मूल फ़ाइलें डाउनलोड करने) के लिए।</li>
<li><b>फ़ाइलें और फ़ोल्डर एक्सेस</b>: <b>फ़ोल्डर चुनें</b> पर टैप करने पर केवल आपके द्वारा चुने गए फ़ोल्डर को पढ़ने के लिए।</li>
<li><b>लोकल नेटवर्क और इंटरनेट</b>: केवल आपके FTP, SFTP या WebDAV सर्वर से कनेक्ट होने के लिए।</li>
<li><b>बैकग्राउंड ऐप रिफ़्रेश और नोटिफ़िकेशन</b>: केवल शेड्यूल किए गए बैकअप (<code>BGTaskScheduler</code>) चलाने और स्थिति बताने के लिए।</li>
</ul>""",
            ),
            (
                "security",
                "6. डेटा सुरक्षा और अखंडता",
                """<ul>
<li><b>एन्क्रिप्टेड प्रोटोकॉल</b>: <b>SFTP (SSH)</b> और <b>HTTPS WebDAV</b> के ज़रिए सुरक्षित ट्रांसफ़र।</li>
<li><b>SFTP होस्ट कुंजी जाँच</b>: पहली बार कनेक्ट होने पर सर्वर की SSH पहचान याद रखता है और बदलने पर चेतावनी देता है।</li>
<li><b>चेकसम (Checksum)</b>: अपलोड की गई फ़ाइलों की अखंडता जाँचने का विकल्प।</li>
<li><b>कीचेन सुरक्षा</b>: iOS कीचेन में हार्डवेयर-सुरक्षित पासवर्ड एन्क्रिप्शन।</li>
</ul>""",
            ),
            (
                "third-party",
                "7. तृतीय-पक्ष सेवाएँ",
                """<p>BackupFlow डेटा संग्रह, एनालिटिक्स या विज्ञापन के लिए किसी भी तृतीय-पक्ष सेवा से नहीं जुड़ता और केवल आपके द्वारा सेट किए गए सर्वर से संवाद करता है।</p>""",
            ),
            (
                "children",
                "8. बच्चों की गोपनीयता",
                """<p>BackupFlow 13 वर्ष से कम उम्र के बच्चों सहित किसी से भी कोई व्यक्तिगत जानकारी एकत्र नहीं करता है।</p>""",
            ),
            (
                "your-rights",
                "9. आपके अधिकार, नियंत्रण और डेटा रीसेट",
                """<p>आपके iPhone पर आपके डेटा का पूरा नियंत्रण आपके पास है:</p>
<ul>
<li><b>बैकअप हब</b> से कभी भी अपने टास्क और सर्वर संपादित या डिलीट करें।</li>
<li><b>बैकअप इतिहास</b> में लॉग साफ़ करें या <b>सेटिंग्स › इतिहास अवधारण (दिन)</b> में समय बदलें।</li>
<li><b>सेटिंग्स › सभी डेटा रीसेट करें</b> पर टैप करके (या ऐप हटाकर) इस डिवाइस से सभी टास्क, इतिहास और सहेजे गए पासवर्ड तुरंत मिटाएँ। आपके सर्वर की फ़ाइलों को छुआ नहीं जाता।</li>
</ul>""",
            ),
            (
                "changes",
                "10. इस गोपनीयता नीति में बदलाव",
                """<p>इस नीति में कोई भी बदलाव होने पर नई तारीख के साथ इसी पेज पर प्रकाशित किया जाएगा।</p>""",
            ),
            (
                "contact",
                "11. संपर्क जानकारी",
                """<p>किसी भी प्रश्न के लिए ऐप में <b>सेटिंग्स › सहायता से संपर्क करें</b> या ईमेल के माध्यम से संपर्क करें:</p>
<ul>
<li><b>ईमेल</b>: <a href="mailto:tamersavasci@icloud.com">tamersavasci@icloud.com</a></li>
<li><b>डेवलपर</b>: Tamer Savaşcı</li>
</ul>""",
            ),
            (
                "compliance",
                "12. कानूनी अनुपालन (GDPR / CCPA)",
                """<p>BackupFlow कोई व्यक्तिगत डेटा एकत्र नहीं करता है, इसलिए यह डिज़ाइन के रूप में ही <b>GDPR</b>, <b>CCPA</b> और अंतरराष्ट्रीय गोपनीयता कानूनों का पूर्ण पालन करता है।</p>""",
            ),
        ],
    },
}
