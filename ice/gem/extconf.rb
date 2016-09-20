# **********************************************************************
#
# Copyright (c) 2003-2016 ZeroC, Inc. All rights reserved.
#
# This copy of Ice is licensed to you under the terms described in the
# ICE_LICENSE file included in this distribution.
#
# **********************************************************************

require "mkmf"

if ! (RUBY_PLATFORM =~ /mswin|mingw/)
	#
	# On OSX & Linux bzlib.h is required.
	#
	if not have_header("bzlib.h") then
	    exit 1
	end


	if RUBY_PLATFORM =~ /linux/
		#
		# On Linux openssl is required for IceSSL.
		#
		if not have_header("openssl/ssl.h") then
		    exit 1
		end
	end
end

#
# Ice on OSX is built only with 64 bit support.
#
if RUBY_PLATFORM =~ /darwin/
	$ARCH_FLAG = "-arch x86_64"
end

$INCFLAGS << ' -Iice/cpp/include'
$INCFLAGS << ' -Iice/cpp/include/generated'
$INCFLAGS << ' -Iice/cpp/src'

$CPPFLAGS << ' -DICE_STATIC_LIBS'

if RUBY_PLATFORM =~ /mswin|mingw/
	# Change -D_WIN32_WINNT=0x0501 to # Change -D_WIN32_WINNT=0x0601 otherwise the IceSSL plugin won't compile
	$CPPFLAGS = $CPPFLAGS.sub("501", "601")

	$CPPFLAGS << ' -DWIN32_LEAN_AND_MEAN'
	$CPPFLAGS << ' -DICE_BUILDING_ICEUTIL'
	$CPPFLAGS << ' -DICE_BUILDING_SLICE'
	$CPPFLAGS << ' -DICE_BUILDING_ICE'
	$CPPFLAGS << ' -DICE_BUILDING_ICESSL'
	$CPPFLAGS << ' -mthreads'

	$INCFLAGS << ' -Iice/bzip2'

	# -lws2_32 must be in LOCAL_LIBS even though mkmk puts it at the end of the LIBS, otherwise
	# you get error 6 when using the socket library.
	$LOCAL_LIBS << ' -lShlwapi -lrpcrt4  -ladvapi32 -lIphlpapi -lsecur32 -lcrypt32 -lws2_32'

	# statically link the C and C++ runtimes.
	$LDFLAGS << ' -static-libgcc -static-libstdc++'
elsif RUBY_PLATFORM =~ /darwin/
	$LOCAL_LIBS << ' -framework Security -framework CoreFoundation'
elsif RUBY_PLATFORM =~ /linux/
	$LOCAL_LIBS << ' -lssl -lcrypto -lbz2 -lrt'
        if RUBY_VERSION =~ /1.8/
            # With 1.8 we need to link with C++ runtime, as gcc is used to link the extension
            $LOCAL_LIBS << ' -lstdc++'
            # With 1.8 we need to fix the objects output directory
            $CPPFLAGS << ' -o$@'
            # With 1.8 /usr/lib/ruby/1.8/regex.h conflicts with /usr/include/regex.h
            # we add a symbolic link to workaround the problem
            if File.exist?('/usr/include/regex.h') && !File.exist?('regex.h')
                FileUtils.ln_s '/usr/include/regex.h', 'regex.h'
            end
        end
end
$CPPFLAGS << ' -w'

# Setup the object and source files.
$objs = []
$srcs = []

# Add the plugin source.
Dir["*.cpp"].each do |f|
	$objs << File.basename(f, ".*") + ".o"
	$srcs << f
end

# The Ice source.
skip = []
if RUBY_PLATFORM =~ /mswin|mingw/
	skip << "SysLoggerI.cpp"
end
Dir["ice/**/*.cpp"].each do |f|
	if ! skip.include? File.basename(f)
		$objs << File.dirname(f) + "/" + File.basename(f, ".*") + ".o"
		$srcs << f
	end
end

# The mcpp source.
Dir["ice/mcpp/*.c"].each do |f|
	dir = "ice/mcpp"
	$objs << File.join(dir, File.basename(f, ".*") + ".o")
	$srcs << File.join(dir, f)
end

#
# Add bzip2 source under Windows.
#
if RUBY_PLATFORM =~ /mswin|mingw/
	['blocksort.c', 'bzlib.c', 'compress.c','crctable.c','decompress.c','huffman.c','randtable.c'].each do |f|
		dir = "ice/bzip2"
		$objs << File.join(dir, File.basename(f, ".*") + ".o")
		$srcs << File.join(dir, f)
	end
end

create_makefile "IceRuby"
