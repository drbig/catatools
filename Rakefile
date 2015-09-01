require 'rake/testtask'

GOOSS   = %w{linux windows darwin}
GOARCHS = %w{amd64 386}

Rake::TestTask.new do |t|
  t.name = 'test:all'
  t.warning = true
  t.test_files = FileList['*_test.rb']
end

namespace :build do
  desc 'Build all possible Go binaries'
  task :go do
    FileList['*.go'].each do |source|
      name = File.basename(source, '.go')
      GOOSS.each do |os|
        GOARCHS.each do |arch|
          target = "#{name}-#{os}-#{arch}"
          sh "GOOS=#{os} GOARCH=#{arch} go build -o bin/#{target} #{source}"
        end
      end
    end
    sh "cd bin && rm -f checksums.md5 && md5sum * > checksums.md5"
  end
end
