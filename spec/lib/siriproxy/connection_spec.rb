require 'spec_helper'

describe SiriProxy::Connection do

  subject { SiriProxy::Connection.new 'signature' }

  before(:each) do
    @name = "__test_connection"
    subject.send :instance_variable_set, :@name, @name
  end

  context "#inheritence" do
    it "should inherit from EventMachine::Connection" do
      subject.class.superclass.should == EventMachine::Connection
    end
  end

  context "#initialize" do
    its(:processed_headers) { should be_false }
    its(:output_buffer)     { should be_empty }
    its(:input_buffer)      { should be_empty }
    its(:unzipped_output)   { should be_empty }
    its(:unzipped_input)    { should be_empty }
    its(:unzip_stream)      { should be_instance_of Zlib::Inflate }
    its(:zip_stream)        { should be_instance_of Zlib::Deflate }
    its(:consumed_ace)      { should be_false }
  end

  context "#post_init" do
    it "should set ssled to false" do
      subject.post_init

      subject.ssled.should be_false
    end
  end

  context "#ssl_handshake_completed" do
    it "should set ssled to true" do
      subject.ssl_handshake_completed

      subject.ssled.should be_true
    end

    it "should puts nothing if $LOG_LEVEL <= 1" do
      capture(:stdout) { subject.ssl_handshake_completed }.
        should puts ""
    end

    it "should puts a message if $LOG_LEVEL > 1" do
      $LOG_LEVEL = 2

      capture(:stdout) { subject.ssl_handshake_completed }.
        should puts "[Info - #{@name}] SSL completed for #{@name}"
    end
  end

  context "#receive_line" do
    before(:each) do
      subject.stubs(:flush_output_buffer)
      subject.stubs(:set_binary_mode)
    end

    it "should puts nothing if LOG_LEVEL <= 2" do
      $LOG_LEVEL = 2
      capture(:stdout) { subject.receive_line "something" }.
        should puts nil
      capture(:stdout) { subject.receive_line "" }.
        should puts nil
    end

    context "headers" do
      before(:each) do
        @line = "_test_receive_line"
      end

      it "should puts a message if LOG_LEVEL > 2" do
        capture(:stdout) { subject.receive_line @line }.
          should_not puts "[Header - #{@name}] #{@line}"

        $LOG_LEVEL = 3
        capture(:stdout) { subject.receive_line @line }.
          should puts "[Header - #{@name}] #{@line}"
      end

      it "should not call set_binary_mode" do
        subject.expects(:set_binary_mode).never

        subject.receive_line @line
      end

      it "should not set processed_headers to true" do
        subject.receive_line @line

        subject.processed_headers.should be_false
      end

      it "should append CR-LF to line and add it to the output_buffer" do
        subject.receive_line @line
        subject.output_buffer.should == "#{@line}\x0d\x0a"
      end

      it "should call flush_output_buffer" do
        subject.expects(:flush_output_buffer).once

        subject.receive_line @line
      end
    end

    context "end of headers" do
      before(:each) do
        @line = ""
      end

      it "should puts a message if LOG_LEVEL > 2" do
        capture(:stdout) { subject.receive_line @line }.
          should_not puts "[Header - #{@name}] #{@line}"

        $LOG_LEVEL = 3
        capture(:stdout) { subject.receive_line @line }.
          should puts "[Header - #{@name}] #{@line}"
      end

      it "should puts another message (telling that the end of headers is reached" do
        capture(:stdout) { subject.receive_line @line }.
          should_not puts "[Debug - #{@name}] Found end of headers"

        $LOG_LEVEL = 4
        capture(:stdout) { subject.receive_line @line }.
          should puts "[Debug - #{@name}] Found end of headers"
      end

      it "should call set_binary_mode" do
        subject.expects(:set_binary_mode).once

        subject.receive_line @line
      end

      it "should set processed_headers to true" do
        subject.receive_line @line

        subject.processed_headers.should be_true
      end

      it "should append CR-LF to line and add it to the output_buffer" do
        subject.receive_line @line
        subject.output_buffer.should == "#{@line}\x0d\x0a"
      end

      it "should call flush_output_buffer" do
        subject.expects(:flush_output_buffer).once

        subject.receive_line @line
      end
    end
  end

  context "#receive_binary_data" do
    before(:each) do
      subject.stubs(:process_compressed_data)
      subject.stubs(:flush_output_buffer)

      @data_to_consume = 0xAACCEE02
      @data = ""
    end
  end
end
