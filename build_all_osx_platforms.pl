
use Cwd;
use Cwd 'abs_path';
use Getopt::Long;
use File::Basename;
use File::Path;

my $currentdir = getcwd();

my $monoroot = File::Spec->rel2abs(dirname(__FILE__) . "/../..");
my $monoroot = abs_path($monoroot);
my $buildscriptsdir = "$monoroot/external/buildscripts";
my $buildMachine = $ENV{UNITY_THISISABUILDMACHINE};
my $buildsroot = "$monoroot/builds";

my @passAlongArgs = ();
foreach my $arg (@ARGV)
{
	# Filter out --clean if someone uses it.  We have to clean since we are doing two builds
	if (not $arg =~ /^--clean=/)
	{
		push @passAlongArgs, $arg;
	}
}

print(">>> Building i386\n");
system("perl", "$buildscriptsdir/build_all.pl", "--arch32=1", "--clean=1", @passAlongArgs) eq 0 or die ('failing building i386');

print(">>> Building x86_64\n");
system("perl", "$buildscriptsdir/build_all.pl", "--clean=1", @passAlongArgs) eq 0 or die ('failing building x86_64');

# Merge stuff in the embedruntimes directory
my $embedDirRoot = "$buildsroot/embedruntimes";
my $embedDirDestination = "$embedDirRoot/osx";
my $embedDirSource32 = "$embedDirRoot/osx-tmp-i386";
my $embedDirSource64 = "$embedDirRoot/osx-tmp-x86_64";

# Make sure the directory for our destination is clean before we copy stuff into it
if (-d "$embedDirDestination")
{
	print(">>> Cleaning $embedDirDestination\n");
	rmtree($embedDirDestination);
}

system("mkdir -p $embedDirDestination");

if (!(-d $embedDirSource32))
{
	die("Expected source directory not found : $embedDirSource32\n");
}

if (!(-d $embedDirSource64))
{
	die("Expected source directory not found : $embedDirSource64\n");
}

# Create universal binaries
for my $file ('libmono.0.dylib','libmono.a','libMonoPosixHelper.dylib')
{
	system ('lipo', "$embedDirSource32/$file", "$embedDirSource64/$file", '-create', '-output', "$embedDirDestination/$file");
}

if (not $buildMachine)
{
	for my $file ('libmono.0.dylib','libMonoPosixHelper.dylib')
	{
		rmtree ("$embedDirDestination/$file.dSYM");
		system ('dsymutil', "$embedDirDestination/$file") eq 0 or warn ("Failed creating $embedDirDestination/$file.dSYM");
	}
}

system('cp', "$embedDirSource32/MonoBundleBinary", "$embedDirDestination/MonoBundleBinary");

# Merge stuff in the monodistribution directory
my $distDirRoot = "$buildsroot/monodistribution";
my $distDirDestinationBin = "$buildsroot/monodistribution/bin";
my $distDirDestinationLib = "$buildsroot/monodistribution/lib";
my $distDirSourceBin32 = "$distDirRoot/bin-osx-tmp-i386";
my $distDirSourceBin64 = "$distDirRoot/bin-osx-tmp-x86_64";

# Should always exist because build_all would have put stuff in it, but in some situations
# depending on the options it may not.  So create it if it does not exist
if (!(-d $distDirDestinationBin))
{
	system("mkdir -p $distDirDestinationBin");
}

if (!(-d $distDirDestinationLib))
{
	system("mkdir -p $distDirDestinationLib");
}

if (!(-d $distDirSourceBin32))
{
	die("Expected source directory not found : $distDirSourceBin32\n");
}

if (!(-d $distDirSourceBin64))
{
	die("Expected source directory not found : $distDirSourceBin64\n");
}
 
for my $file ('mono','pedump')
{
	system ('lipo', "$distDirSourceBin32/$file", "$distDirSourceBin64/$file", '-create', '-output', "$distDirDestinationBin/$file");
}

#Create universal binaries for stuff is in the embed dir but will end up in the dist dir
for my $file ('libMonoPosixHelper.dylib')
{
	system ('lipo', "$embedDirSource32/$file", "$embedDirSource64/$file", '-create', '-output', "$distDirDestinationLib/$file");
}

if ($buildMachine)
{
	print(">>> Clean up temporary arch specific build directories\n");
	
	rmtree("$distDirSourceBin32");
	rmtree("$distDirSourceBin64");
	rmtree("$embedDirSource32");
	rmtree("$embedDirSource64");
}