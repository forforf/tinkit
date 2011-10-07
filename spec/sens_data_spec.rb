require_relative "../lib/helpers/require_helper"
require 'fileutils'
require 'psych'

require Tinkit.config 'sens_data'

module SensDataHelper
  def self.make_yaml_file(fname, data)
    yaml = Psych.dump data
    File.open(fname, 'w'){|f| f.write(yaml)}
  end
end

describe SensData do
  before :each do
    @tmp_file = "/tmp/sens_data"
    @data = {
      'avail_stores' => {
        'iris' => {
          'type' => 'couchdb',
          'host' => 'foo.iriscouch.com',
          'user' => nil
        }
      }
    }
    SensDataHelper.make_yaml_file @tmp_file, @data

    @tmp_file_invalid = "/tmp/sens_data_invalid"
    inv_data = {'foo' => 'bar'}
    SensDataHelper.make_yaml_file @tmp_file_invalid, inv_data
    @tmp_file_empty = "/tmp/sens_data_empty"
    FileUtils.touch @tmp_file_empty
  end

  after :each do
    FileUtils.rm @tmp_file if File.exist? @tmp_file
    FileUtils.rm @tmp_file_invalid if File.exist? @tmp_file_invalid
    FileUtils.rm @tmp_file_empty if File.exist? @tmp_file_empty
  end
   
  it "should raise error if config file doesnt exist" do
    expect{SensData.load("/road/to/nowhere")}.to raise_error(IOError)
  end

  it "should fail if the config file is invalid" do
    expect{SensData.load(@tmp_file_invalid)}.to raise_error(SensData::ParseError)
  end

  it "should load valid data" do
    SensData.load(@tmp_file).should == @data
  end
end
=begin
  it "should work with a valid file location" do
    FileUtils.touch(@tmp_file)
    TinkitConfig.set_config_file_location(@tmp_file).should == @tmp_file
  end

  #it "should raise an error if the file has been moved or deleeted" do
  #  moving_file = "/tmp/sens_data"
  #  `touch #{moving_file}`
  #  TinkitConfig.set_config_file_location(moving_file).should == moving_file
  #  `rm #{moving_file}`

end
=end
