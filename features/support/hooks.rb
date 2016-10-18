Before('@sudo') do
  raise 'sudo authentication failed' unless system 'sudo -v'
  @aruba_timeout_seconds = 15
end

After('@sudo') do
  run 'trema killall --all -S.'
  sleep 10
end
