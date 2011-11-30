require 'spec_helper'

describe SiriProxy::Connection do

  subject { SiriProxy::Connection.new 'signature' }

  before(:each) do
    @name = "__test_connection"
    @ace  = File.read(File.join(FIXTURES_PATH, 'ace.bin'))
    @data = File.read(File.join(FIXTURES_PATH, 'bin_with_ace.bin'))
    @data_without_ace = File.read(File.join(FIXTURES_PATH, 'bin_without_ace.bin'))
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
    end

    context "ace not removed" do
      it "should add it to input_buffer" do
        subject.receive_binary_data @data

        subject.input_buffer.should_not be_empty
      end

      it "should set remove the ace from the input_buffer" do
        subject.receive_binary_data @data

        subject.input_buffer.should == @data_without_ace
      end

      it "should append the ace to the output buffer" do
        subject.receive_binary_data @data

        subject.output_buffer.should include @ace
      end

      it "should set consumed_ace to true" do
        subject.receive_binary_data @data

        subject.consumed_ace.should be_true
      end

      it "should call process_compressed_data" do
        subject.expects(:process_compressed_data).once

        subject.receive_binary_data @data
      end

      it "should call flush_output_buffer" do
        subject.expects(:flush_output_buffer).once

        subject.receive_binary_data @data
      end
    end

    context "ace removed" do
      before(:each) do
        subject.consumed_ace = true
      end

      it "should add data to input_buffer unmodified" do
        subject.receive_binary_data @data_without_ace

        subject.input_buffer.should == @data_without_ace
      end

      it "should not touch the output buffer" do
        subject.receive_binary_data @data_without_ace

        subject.output_buffer.should be_empty
      end

      it "should call process_compressed_data" do
        subject.expects(:process_compressed_data).once

        subject.receive_binary_data @data
      end

      it "should call flush_output_buffer" do
        subject.expects(:flush_output_buffer).once

        subject.receive_binary_data @data
      end
    end
  end

  context "#flush_output_buffer" do
    context 'without output buffer' do
      it "should return if output buffer is empty" do
        subject.output_buffer = ""

        subject.flush_output_buffer.should be_nil
      end

      it "should not call other_connection" do
        subject.expects(:other_connection).never

        subject.flush_output_buffer
      end
    end

    context 'with output buffer' do
      before(:each) do
        subject.output_buffer = @ace
        @other_connection = mock "other connection"
        @other_connection.stubs(:ssled).returns(false)
        @other_connection.stubs(:send_data)
        @other_connection.stubs(:name).returns("__test_other_connection")

        subject.stubs(:other_connection).returns(@other_connection)
      end

      context "other connection ssled" do
        before(:each) do
          @other_connection.stubs(:ssled).returns(true)
        end

        it "should check if the other connection is ssled" do
          @other_connection.expects(:ssled).returns(true).once

          subject.flush_output_buffer
        end

        it "should not puts a message if LOG_LEVEL is <= 5" do
          $LOG_LEVEL = 5

          capture(:stdout) { subject.flush_output_buffer }.
            should_not puts "[Debug - #{@name}] Forwarding #{@ace.length} bytes of data to #{@other_connection.name}"
        end

        it "should puts a message if LOG_LEVEL is > 5" do
          $LOG_LEVEL = 6

          capture(:stdout) { subject.flush_output_buffer }.
            should puts "[Debug - #{@name}] Forwarding #{@ace.length} bytes of data to #{@other_connection.name}"
        end

        it "should call other_connection.send_data(output_buffer)" do
          @other_connection.expects(:send_data).with(@ace).once

          subject.flush_output_buffer
        end

        it "should clear out the output buffer" do
          subject.flush_output_buffer

          subject.output_buffer.should be_empty
        end
      end

      context "other connection not ssled" do
        it "should puts a message if LOG_LEVEL <= 5" do
          $LOG_LEVEL = 5

          capture(:stdout) { subject.flush_output_buffer }.
            should_not puts "[Debug - #{@name}] Buffering some data for later (#{@ace.length} bytes buffered)"
        end

        it "should puts a message if LOG_LEVEL is greater than 5" do
          $LOG_LEVEL = 6

          capture(:stdout) { subject.flush_output_buffer }.
            should puts "[Debug - #{@name}] Buffering some data for later (#{@ace.length} bytes buffered)"
        end

        it "should not clear out the buffer" do
          subject.flush_output_buffer

          subject.output_buffer.should == @ace
        end

        it "should not call other_connection.send_data(output_buffer)" do
          @other_connection.expects(:send_data).with(@ace).never

          subject.flush_output_buffer
        end
      end
    end
  end

  context "#process_compressed_data" do

  end

  context "#has_next_object?" do

  end

  context "#read_next_object_from_unzipped" do

  end

  context "#parse_object" do

  end

  context "#inject_object_to_output_stream" do

  end

  context "#flush_unzipped_output" do

  end

  context "#prep_received_object" do

  end

  context "#received_object" do

  end
end
