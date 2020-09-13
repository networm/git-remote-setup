#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

$rules =
[
  "ProjectSettings/*",
  "Assets/Resources/GameSettings.asset",
]

$commit_rules =
[
  '^JIRA-\d+',
]

$has_error = false

def error(msg)
  puts "[POLICY] #{msg}"
  $has_error = true
end

def get_author_data(author_file)
    author_file = File.read(author_file).split("\n").reject { |line| line == '' or line.start_with? '#'}
    access = {}
    author_file.each do |line|
      user, email = line.split(' | ')
      access[user] ||= email
    end
    return access
end

def check_author_data
  if $newrev == $zero
    # delete remote branch
    return
  end
  if $oldrev == $zero
    # list everything reachable from newrev but not any heads
    new_commits = `git rev-list #{$newrev} --not --branches=*`.split("\n")
  else
    new_commits = `git rev-list #{$oldrev}..#{$newrev}`.split("\n")
  end
  access = get_author_data('custom_hooks/git-author.txt')
  new_commits.each do |rev|
    line = `git log -1 --pretty="%an|%ae|%cn|%ce" #{rev}`
    author_name, author_email, commiter_name, commiter_email = line.chomp.split('|')

    if access[author_name] != author_email
      error "错误的作者：名字 '#{author_name}' 邮箱 '#{author_email}' 提交：'#{rev}'"
    end

    if author_name != commiter_name and access[commiter_name] != commiter_email
      error "错误的提交者：名字 '#{commiter_name}' 邮箱 '#{commiter_email}' 提交：'#{rev}'"
    end

    message = `git log -1 --pretty="%s" #{rev}`
    message = message.to_s.force_encoding("UTF-8").chomp

    if message.index("Merge") == 0 or message.index("Revert") == 0
      continue
    end

    $commit_rules.each do |commit_rule|
      if !message.match(/#{commit_rule}/)
        error "提交：'#{rev}' 信息格式不符合 '#{commit_rule}' - '#{message}'"
      end
    end
  end
end

def check_wrong_merge
  if $newrev == $zero
    # delete remote branch
    return
  end

  if $newrev == $zero || $oldrev == $zero || `git cat-file -t #{$newrev}`.chomp != "commit" || `git merge-base #{$oldrev} #{$newrev}`.chomp != $oldrev
    return
  end

  commits = `git rev-list --first-parent --reverse #{$oldrev}..#{$newrev}`.chomp
  if commits.empty?
    return
  end

  first_commit = commits.split("\n").first
  if first_commit.empty?
    return
  end

  parent = `git rev-parse --verify #{first_commit}^1`.chomp
  if parent != $oldrev
    error "你需要移除错误合并提交：\"#{first_commit}\""
  end
end

def check_files_rules
  if $newrev == $zero
    # delete remote branch
    return
  end

  if $oldrev == $zero
    # list everything reachable from newrev but not any heads
    new_commits = `git rev-list #{$newrev} --not --branches=* --no-merges`.split("\n")
  else
    new_commits = `git rev-list #{$oldrev}..#{$newrev} --no-merges`.split("\n")
  end

  new_commits.each do |rev|
    message = `git log -1 --pretty="%s" #{rev}`
    message = message.to_s.force_encoding("UTF-8")
    files = `git diff --name-only -z #{rev}~..#{rev}`.to_s.force_encoding("UTF-8").split("\0")
    files.each do |file|
      $rules.each do |rule|
        filename = File.basename(file, ".*")
        if file =~ /#{rule}/ and !message.include? filename
          error "错误：要提交 \"#{file}\" 文件，提交信息标题中必须包含 \"#{filename}\"，提交 \"#{rev}\""
        end
      end
    end
  end
end

$refname = ARGV[0]
$oldrev = ARGV[1]
$newrev = ARGV[2]
$user = ENV['USER']
$zero = '0000000000000000000000000000000000000000'
puts "应用策略中"
puts "(#{$refname}) (#{$oldrev[0,6]}) (#{$newrev[0,6]})"
puts ""
puts "检查错误合并提交"
check_wrong_merge
puts ""
puts "检查作者信息"
check_author_data
puts ""
puts "检查误提交文件"
check_files_rules

if $has_error
  error "你需要修正以上问题"
  exit 1
end
