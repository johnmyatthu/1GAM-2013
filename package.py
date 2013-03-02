import zipfile
import os
import fnmatch
import re
import subprocess
import shlex
import stat

# the root folder to package
PROJECT_PATH = "."

# the generated love binary (runnable binary + package)
PROJECT_NAME = "treasuretrove"

# the generated love package
PACKAGE_NAME = "%s.love" % PROJECT_NAME

def host_platform():
	from platform import platform
	p = platform().lower()

	if 'darwin' in p:
		hostplatform = 'macosx'
	elif 'linux' in p or 'nix' in p:
		hostplatform = 'linux'		
	elif 'win' in p or 'nt' in p:
		hostplatform = 'windows'


	return hostplatform

def love_binary_path():
	love_paths = {
		"macosx" : "/Applications/love.app",
		"windows" : "",
		"linux" : "/usr/bin/love"
	}

	return love_paths[ host_platform() ]

def platform_generate_binary( archive, vars ):
	lovepath = love_binary_path()

	commands = {
		'linux' : [
			'gzip %(temp)s/%(project_name)s'
		],
		'macosx' : [
			'mkdir -p %(temp)s',
			'cp -R %(source)s %(temp)s',
			'mkdir -p %(temp)s/%(project_name)s.app/Contents/Resources',
			'cp -R %(archive)s %(temp)s/%(project_name)s.app/Contents/Resources'
		],
		'windows' : []
	}

	try:
		os.makedirs( "%(temp)s" % vars )
	except OSError:
		pass
	except:
		raise

	if host_platform() == "linux":
		target = "%s/%s" % (vars['temp'], vars['project_name'])
		f = open( target, "wb" )
		love = open( vars['source'], "rb" ).read()
		f.write( love )
		package = open( vars['archive'], "rb" ).read()
		f.write( package )
		f.close()
		os.chmod( target, stat.S_IXUSR | stat.S_IWUSR | stat.S_IRUSR | stat.S_IXGRP | stat.S_IXOTH | stat.S_IRGRP | stat.S_IROTH )

	for cmd in commands[ host_platform() ]:
		command = (cmd % vars)
		print( command )
		process = subprocess.check_call( shlex.split(command), shell=host_platform()=='windows' )

# the archive name that will be created (.love)
archive = os.path.abspath( os.path.join(PROJECT_PATH, PACKAGE_NAME ))


def zip_files_to_archive( files, archive ):
	z = zipfile.ZipFile( archive, 'w' )

	# add files to the zip
	for f in files:
		z.write( f )

	z.close()


def create_file_list( root_path, excludes ):
	
	excludes = r'|'.join( [fnmatch.translate(x) for x in excludes] ) or r'$.'

	archive_files = []

	
	#os.chdir( PROJECT_PATH )

	for root, dirs, files in os.walk( root_path, topdown=True ):
		# exclude directories
		#dirs[:] = [os.path.join(root, d) for d in dirs]
		dirs[:] = [d for d in dirs if not re.match(excludes,d)]

		# exclude/include files
		files = [os.path.join(root, f) for f in files]
		files = [f for f in files if not re.match(excludes, f)]

		for filename in files:
			archive_files.append( filename )

	return archive_files

if __name__ == "__main__":

	excludes = [ '.git', 'CVSROOT', '.gitignore', '.gitmodules', '*.psd', '*.sublime-*', '.DS_Store' ]

	# if package already exists; purge it
	if os.path.exists( PACKAGE_NAME ):
		os.unlink( PACKAGE_NAME )


	# zip the files into a .love bundle
	archive_files = create_file_list( ".", excludes )
	zip_files_to_archive( archive_files, archive )
	
	variables = {
		'source' : love_binary_path(),
		'archive' : archive,
		'temp' :  os.path.abspath('output'),
		'project_name' : PROJECT_NAME
	}
	
	# create a platform-specific package
	platform_generate_binary( archive, variables )
