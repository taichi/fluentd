require "ffi"
 
module Win32
  extend FFI::Library
 
  ffi_lib 'kernel32'
  ffi_convention :stdcall
  
  typedef :uint       , :DWORD
  typedef :pointer    , :HANDLE
  typedef :bool       , :BOOL
  typedef :ulong_long , :ULONGLONG
  
  typedef :pointer  , :LPTSTR
  typedef :pointer  , :LPCTSTR
  typedef :pointer  , :LPCVOID
  typedef :pointer  , :LPSECURITY_ATTRIBUTES
  
  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms724284(v=vs.85).aspx
  class FILETIME < FFI::Struct
    layout(
      :dwLowDateTime , :DWORD,
      :dwHighDateTime, :DWORD,
    )
  end
  
  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa363788(v=vs.85).aspx
  class FILE_INFORMATION < FFI::Struct
    layout(
      :dwFileAttributes,     :DWORD   ,
      :ftCreationTime,        FILETIME,
      :ftLastAccessTime,      FILETIME,
      :ftLastWriteTime,       FILETIME,
      :dwVolumeSerialNumber, :DWORD   ,
      :nFileSizeHigh,        :DWORD   ,
      :nFileSizeLow,         :DWORD   ,
      :nNumberOfLinks,       :DWORD   ,
      :nFileIndexHigh,       :DWORD   ,
      :nFileIndexLow,        :DWORD   ,
    )
  end
  
  INVALID_HANDLE_VALUE = -1
  
  # http://msdn.microsoft.com/ja-jp/library/windows/desktop/ms724211(v=vs.85).aspx
  attach_function :CloseHandle, [:HANDLE], :BOOL
  
  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa374892(v=vs.85).aspx
  GENERIC_READ  = 0x80000000
  
  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa363858(v=vs.85).aspx
  FILE_SHARE_READ  = 0x00000001
  FILE_SHARE_WRITE = 0x00000002
  FILE_SHARE_DELETE= 0x00000004
  
  OPEN_EXISTING         = 3
  FILE_ATTRIBUTE_NORMAL = 0x00000080
  
  attach_function :CreateFile, :CreateFileW, [
    :LPCTSTR               , # lpFileName,
    :DWORD                 , # dwDesiredAccess,
    :DWORD                 , # dwShareMode,
    :LPSECURITY_ATTRIBUTES , # lpSecurityAttributes,
    :DWORD                 , # dwCreationDisposition,
    :DWORD                 , # dwFlagsAndAttributes,
    :HANDLE                , # hTemplateFile
  ], :HANDLE
  
  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa364952(v=vs.85).aspx
  
  typedef :pointer, :LPBY_HANDLE_FILE_INFORMATION
  attach_function :GetFileInformationByHandle, [
    :HANDLE,
    :LPBY_HANDLE_FILE_INFORMATION
  ], :BOOL
  
  def self.last_error(err_at, err = FFI.errno)
    SystemCallError.new(err_at, err)
  end
  
  def self.to_unicode(path)
    (path.tr(::File::SEPARATOR, ::File::ALT_SEPARATOR) + 0.chr).encode('UTF-16LE')
  end
  
  def self.to_large_integer(h, l)
    (h << 32) | l
  end
  
  def self.to_time(ft)
    t = to_large_integer ft[:dwHighDateTime], ft[:dwLowDateTime]
    Time.at t / 10000000 - 11644473600
  end
  
  
  class File
    def self.stat(path)
      share = FILE_SHARE_DELETE | FILE_SHARE_READ | FILE_SHARE_WRITE
      wpath = Win32.to_unicode path
      handle = Win32.CreateFile(wpath, GENERIC_READ, share, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nil)
      
      if INVALID_HANDLE_VALUE == handle.address
        raise Errno::ENOENT.new path
      end
      
      begin
        fi = FILE_INFORMATION.new
        unless Win32.GetFileInformationByHandle(handle, fi)
          raise last_error("GetFileInformationByHandle")
        end
        Stat.new fi
      ensure
        Win32.CloseHandle(handle)
      end
    end
    
    class Stat
      attr_reader :rdev
      attr_reader :ino
      attr_reader :size
      attr_reader :atime
      attr_reader :mtime
      attr_reader :ctime
      
      def initialize(fi)
        @rdev = fi[:dwVolumeSerialNumber]
        @ino  = Win32.to_large_integer fi[:nFileIndexHigh], fi[:nFileIndexLow]
        @size = Win32.to_large_integer fi[:nFileSizeHigh] , fi[:nFileSizeLow]
        @atime = Win32.to_time fi[:ftLastAccessTime]
        @mtime = Win32.to_time fi[:ftLastWriteTime]
        @ctime = Win32.to_time fi[:ftCreationTime]
      end
      
      def to_s
        "#<Win32::File::Stat rdev=#{@rdev} ino=#{@ino} size=#{@size} atime=#{@atime} mtime=#{@mtime} ctime=#{@ctime}>"
      end
    end
  end
end
