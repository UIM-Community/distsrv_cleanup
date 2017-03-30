use strict;
use warnings;
use lib "D:/apps/Nimsoft/perllib";
use lib "D:/apps/Nimsoft/Perl64/lib/Win32API";
use Nimbus::API;
use Nimbus::CFG;
use Nimbus::PDS;
use perluim::logger;
use perluim::main;
use perluim::utils;
use perluim::filemap;

# Declare globals variables
my $probeName       = "distsrv_cleanup";
my $probeVersion    = "1.0";
my $time = time();
my ($Logger,$UIM,$Execution_Date);
my ($Domain,$OutputCache,$OutputDirectory,$Login,$Password,$Audit,$LogDirectory);
my $Main_executed = 0; 

$SIG{__DIE__} = \&dieHandler;

# declare logger!
$Logger = new perluim::logger({
    file => "$probeName.log",
    level => 6
});
$Logger->log(3,"$probeName started at $time!");

# Global Settings
readConfiguration();
nimLogin("$Login","$Password") if defined($Password) && defined($Password);
$UIM = new perluim::main("$Domain");
$Logger->cleanDirectory("$OutputDirectory",$OutputCache); 

sub readConfiguration {
    $Logger->log(3,"Read configuration...");
    my $CFG              = Nimbus::CFG->new("$probeName.cfg");
    $Domain              = $CFG->{"setup"}->{"domain"};
    $Audit               = $CFG->{"setup"}->{"audit"} || "no";
    $OutputDirectory     = $CFG->{"setup"}->{"output_directory"} || "output";
    $OutputCache         = $CFG->{"setup"}->{"output_cache_time"} || 345600;
    $Login               = $CFG->{"setup"}->{"nim_login"};
    $Password            = $CFG->{"setup"}->{"nim_password"};

    $Execution_Date     = perluim::utils::getDate();
    $LogDirectory       = "$OutputDirectory/$Execution_Date";
    perluim::utils::createDirectory($LogDirectory);
}

# Main method!
sub main {

    #
    #  Get hubs array
    #
    my($RC,@HubsArray) = $UIM->getArrayHubs(); 
    if($RC == NIME_OK) {    

        foreach my $hub (@HubsArray) {
            next if $hub->{domain} ne $Domain;
            $Logger->log(4,"--------------------------");
            $Logger->log(3,"Hub name => $hub->{name}");

            # Remove finished jobs from distsrv
            my ($RC_Job) = $hub->archive()->jobRemove(); 
            $Logger->log(6,"Succesfully remove jobs")   if $RC_Job == NIME_OK;
            $Logger->log(1,"Failed to remove jobs")     if $RC_Job != NIME_OK;
            $RC_Job = undef; 

            # Get the distsrv probe
            my ($RC_Probes,@ProbesArray) = $hub->probeList("distsrv");
            if($RC_Probes == NIME_OK) {
                my $distsrv = $ProbesArray[0]; 
                $Logger->log(3,"Probe name => $distsrv->{name}");

                goto end if $Audit eq "yes";

                # Remove install_list section 
                my $RC_SK = $distsrv->setKey("install_list");
                if($RC_SK == NIME_OK) {
                    $Logger->log(3,"Install_list remove (next : Restart probe )");
                    $distsrv->restart(); 
                    goto end;
                }
                $Logger->log(1,"Failed to remove install_list section (RC: $RC_SK)");
                
                end:
            }
            else {
                $Logger->log(1,"Failed to get probesList, (RC: $RC_Probes)");
            }
        }

        return;
    }
    $Logger->log(0,"Failed to get hubs list (RC: $RC)");

}

sub dieHandler {
    my ($err) = @_;
    $Logger->finalTime($time);
	$Logger->log(0,"Program is exiting abnormally : $err");
    $| = 1; # Buffer I/O fix
    sleep(2);
    my $MainExecute = perluim::utils::getDate();
    $Logger->copy("output/$MainExecute");
}

main();
$Logger->finalTime($time);
$Logger->copyTo($LogDirectory);
$Logger->close();
