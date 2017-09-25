use Mix.Config

case Mix.env do
  :dev   -> import_config "config_dev.ex"
  :test  -> import_config "config_test.ex"
end
