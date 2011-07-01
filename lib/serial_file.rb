class SerialFile

  module ClassMethods
    def sender (filename, options = {})
      Sender.new(filename, options)
    end

    def receiver (filename, options = {})
      Receiver.new(filename, options)
    end
  end

  extend ClassMethods
end

module SerialFile::IO
  BLOCK_SIZE = 4096
  POLL_INTERVAL = 0.2

  private

  # Common code from #initialize
  def setup_file (filename)
    @filename = filename
    @f = File.new(filename, "r+:BINARY")
    @size = 16777216  # default to 16M filesize
    @num_blocks = @size / BLOCK_SIZE
    @block = 0
    @block_pos = 4
    @block_serial = 1
  end

  # Common code from #next_block
  def next_block_common
    @block += 1
    @block = 0 if @block >= @num_blocks
    @block_pos = 4
    @block_serial += 1
  end

  # Go to the start of the current block.  Used to write the block header.
  def block_rewind
    @f.pos = @block * BLOCK_SIZE
  end

  # Seek to the current block position.  Used to write data.
  def block_seek
    @f.pos = @block * BLOCK_SIZE + @block_pos
  end
end

class SerialFile::Sender
  include SerialFile::IO

  def initialize (filename, options = {})
    setup_file(filename)
    zero
  end

  def puts (*args)
    args.each do |string|
      string << "\n" if string[-1] != "\n"
      syswrite(string)
    end
  end

  def syswrite (data)
    remaining = data.dup.force_encoding("BINARY")
    while remaining && !remaining.empty?
      fit_in_block = BLOCK_SIZE - @block_pos
      block_write(remaining[0...fit_in_block])
      remaining = remaining[fit_in_block..-1]
    end
  end

  alias print syswrite

  private

  # Wipe out the file to avoid confusion over what data has been used.
  def zero
    @f.rewind
    @num_blocks.times do
      @f.syswrite("\0" * BLOCK_SIZE)
    end
  end

  # Write data to block, but assume data fits in block.  Update block header.
  def block_write (data)
    block_seek
    @f.syswrite(data)
    @block_pos += data.length
    block_write_header
    raise "block overwrite error" if @block_pos > BLOCK_SIZE
    next_block if @block_pos == BLOCK_SIZE
  end

  def block_write_header
    block_rewind
    @f.syswrite([@block_serial, @block_pos].pack("nn"))
  end

  # Call next_block when the previous block is full and we need to prepare the
  # next write to be in the next block.
  def next_block
    next_block_common
    wait_for_block_to_write
  end

  # The next block is ready to be written to if the header is zeros.  As
  # a quick and dirty implementation, just sleep and poll for it.
  def wait_for_block_to_write
    loop do
      block_rewind
      data = @f.sysread(4)
      return if data == "\0\0\0\0"
      sleep POLL_INTERVAL
    end
  end
end

class SerialFile::Receiver
  include SerialFile::IO

  def initialize (filename, options = {})
    setup_file(filename)
    @last_block_header = "\0\0\0\0"
  end

  def readpartial (num_bytes)
    buffer = ""
    loop do
      bytes_ready = block_bytes_waiting_for_read
      bytes_to_read = num_bytes < bytes_ready ? num_bytes : bytes_ready
      return buffer if bytes_to_read.zero?
      buffer << block_read(bytes_to_read)
    end
  end

  def sysread (num_bytes)
    buffer = ""
    while buffer.length < num_bytes do
      wait_for_block_to_read(num_bytes - buffer.length)
      buffer << block_read(@block_bytes_waiting_for_read)
    end
    buffer
  end

  private

  # Kind of like sysread, but num_bytes must read only from the current block
  # and the data must be available (caller checks with
  # block_bytes_waiting_for_read to ensure availability).
  def block_read (num_bytes)
    block_seek
    data = @f.sysread(num_bytes)
    @block_pos += data.length
    raise "block overread error" if @block_pos > BLOCK_SIZE
    next_block if @block_pos == BLOCK_SIZE
    data
  end

  # Call next block when we've read everything from the previous block.  We
  # smash the block header for the block we just finished with to signal to
  # the writer that it can reuse it.
  def next_block
    block_rewind
    @f.syswrite("\0\0\0\0")
    next_block_common
  end

  # The block contains data to read when the serial number matches and the
  # @last_block_header does not match the previous read.
  def wait_for_block_to_read (minimum_available = 1)
    # Adjust minimum_available to be capped at the most bytes the block can hold.
    block_space = BLOCK_SIZE - @block_pos
    minimum_available = block_space if block_space < minimum_available
    sleep POLL_INTERVAL while block_bytes_waiting_for_read < minimum_available
  end

  # Return the number of bytes in the current block that are available for
  # reading.
  def block_bytes_waiting_for_read
    block_rewind
    data = @f.sysread(4)
    data_serial, new_pos = data.unpack("nn")
    if @block_serial == data_serial && data != @last_block_header
      @last_block_header = data
      return @block_bytes_waiting_for_read = new_pos - @block_pos
    end
    0
  end
end
