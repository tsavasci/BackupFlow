platform :ios, '17.0'
use_frameworks!

target 'BackupFlow' do
  pod 'NMSSH'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings['CLANG_MODULE_VERIFIER'] = 'NO'
    end
  end

  nmssh_file = File.join(installer.sandbox.root.to_s, 'NMSSH', 'NMSSH', 'NMSSHSession.m')
  if File.exist?(nmssh_file)
    contents = File.read(nmssh_file)
    marker = "Prefer fast, widely supported ciphers for libssh2 1.8.x builds."
    unless contents.include?(marker)
      insert_after = "[self setSession:libssh2_session_init_ex(NULL, NULL, NULL, (__bridge void *)(self))];"
      snippet = <<~'CODE'
        // Prefer fast, widely supported ciphers for libssh2 1.8.x builds.
        const char *preferredCiphers = "aes128-ctr,aes256-ctr";
        libssh2_session_method_pref(self.session, LIBSSH2_METHOD_CRYPT_CS, preferredCiphers);
        libssh2_session_method_pref(self.session, LIBSSH2_METHOD_CRYPT_SC, preferredCiphers);
      CODE
      if contents.include?(insert_after)
        indented = snippet.lines.map { |line| "    " + line }.join.rstrip
        contents = contents.sub(insert_after, "#{insert_after}\n\n#{indented}")
        File.write(nmssh_file, contents)
        puts "✅ NMSSH cipher patch applied"
      else
        puts "⚠️ NMSSHSession.m pattern not found; cipher patch skipped"
      end
    end
  end
end
