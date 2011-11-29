RSpec.configure do |config|
  config.before(:each) do
    $LOG_LEVEL = 1
  end
end
