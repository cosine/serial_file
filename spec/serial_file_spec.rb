require "serial_file"
require "tempfile"

describe SerialFile do

  # Basic smoke test.
  it "should send data to the other end" do
    begin
      tmp = Tempfile.new("foo")
      sender = SerialFile.sender(tmp.path)
      receiver = SerialFile.receiver(tmp.path)
      sender.puts("Hello World")
      receiver.readpartial(1024).should == "Hello World\n"
    ensure
      tmp.unlink
    end
  end

  it "should successfully pass through enough data to loop over the file 3 or more times" do
    data_size = 16777216 * 3
    min_num_loops = data_size / 4096
    data = "abcd123" * 1024

    begin
      tmp = Tempfile.new("foo")
      sender = SerialFile.sender(tmp.path)
      receiver = SerialFile.receiver(tmp.path)
      min_num_loops.should > 0

      min_num_loops.times do
        sender.puts(data)
        receiver.sysread(data.length).should == data
      end
    ensure
      tmp.unlink
    end
  end

  describe "file format" do

    # File format is 4096 byte blocks with 4 byte header and 4092 byte data
    # section.  Header contains two big-endian 16-bit numbers.  First number
    # is a serial number for the block itself that is updated when the block
    # is first used.  It is an indication that the block is ready for reading.
    # The second number is how many bytes in this block have been written to
    # (including header).  Therefore, if a 12 byte string is written to the
    # device, the second number's value would be set to 16.
    #
    # The reader indicates that it has consumed the whole block when it zeros
    # out the 4-byte header.
    #
    # Finally, The writer zeros out the whole file at start up.

    it "should write out a block number and byte count with data" do
      begin
        tmp = Tempfile.new("foo")
        sender = SerialFile.sender(tmp.path)
        sender.puts("Hello World")
        tmp.sysread(17).should == [1, 16, "Hello World\n"].pack("nnZ*")
      ensure
        tmp.unlink
      end
    end

    it "should write to two blocks if the data exceeds space in first block" do
      begin
        tmp = Tempfile.new("foo")
        sender = SerialFile.sender(tmp.path)
        sender.print("A" * 4096)
        tmp.sysread(4096 + 9).should == [1, 4096, "A" * 4092, 2, 8, "A" * 4].pack("nna*nnZ*")
      ensure
        tmp.unlink
      end
    end

    it "should read some data from a block" do
      begin
        tmp = Tempfile.new("foo")
        tmp.print([1, 16, "Hello World\n"].pack("nnZ*"))
        tmp.flush
        receiver = SerialFile.receiver(tmp.path)
        receiver.readpartial(1024).should == "Hello World\n"
      ensure
        tmp.unlink
      end
    end

    it "should read data from two blocks if data exceeds space in first block" do
      begin
        tmp = Tempfile.new("foo")
        tmp.print([1, 4096, "A" * 4092, 2, 8, "A" * 4].pack("nna*nnZ*"))
        tmp.flush
        receiver = SerialFile.receiver(tmp.path)
        receiver.readpartial(4096).should == "A" * 4096
      ensure
        tmp.unlink
      end
    end
  end

end
