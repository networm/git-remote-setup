#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

$commit_rules =
[
  '^Task ID\d+',
  '^Bug ID\d+',
]

$has_error = false

def error(msg)
  puts "[POLICY] #{msg}"
  $has_error = true
end

def check_commit_data
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

  new_commits.each do |rev|
    message = `git log -1 --pretty="%s" #{rev}`
    message = message.to_s.force_encoding("UTF-8").chomp

    if message.index("Merge") == 0 or message.index("Revert") == 0
      continue
    end

    matched = false
    error_message = ""
    $commit_rules.each do |commit_rule|
      if message.match(/#{commit_rule}/)
        matched = true
      else
        error_message += "提交：'#{rev}' 信息格式不符合 '#{commit_rule}' - '#{message}'\n"
      end
    end

    if !matched
      error error_message
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

$refname = ARGV[0]
$oldrev = ARGV[1]
$newrev = ARGV[2]
$user = ENV['USER']
$zero = '0000000000000000000000000000000000000000'
puts "检查范围"
puts "(#{$refname}) (#{$oldrev[0,12]}) (#{$newrev[0,12]})"
puts ""
puts "检查错误合并提交"
check_wrong_merge
puts ""
puts "检查提交信息"
check_commit_data

if $has_error
  error "你需要修正以上问题"
  exit 1
end
