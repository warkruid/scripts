#!/usr/bin/perl -w
#
# $Id: popsweeper.pl,v 0.7 2001/05/20 21:45:15 enneman Exp enneman $
#
# Popsweeper.pl is a very simple mail filter, 
# which checks for spam  mail on the POP server itself. 
#
# Popsweeper can delete unwanted mail before you have to download it 
# to your own computer.
#
# $Id: popsweeper.pl,v 0.7 2001/05/20 21:45:15 enneman Exp enneman $
#
#
# Popsweeper only lets email trough that is:
# 1. directly adressed to you.
# 2. on a list of exceptions.	(ie. a list of mailinglists you are 
#                                subcribed to)
# 3. smaller then a size specified by you. (avoid being hosed by gigantic 
#                                           attachments)
# 4. has an unique message-id   (this is a simple duplicate/mailbomb check!)
#
#
# Popsweeper.pl is a noninteractive script which logs its succes/failure
# to a logfile named popsweeper.log. Start this script before you fire up
# your regular email client (or fetchmail).
#
# The author makes no claim that popsweeper will catch all spam, 
# or even that this  script will be safe to use! 
#
# Copyright (C) 2000-2001 H.J. Enneman
# 
# This program is free software; you can redistribute it and/or modify 
# it under the terms of the GNU General Public License as published by 
# the Free Software Foundation; either version 2 of the License, or 
# (at your option) any later version. 
# 
# This program is distributed in the hope that it will be useful, 
# but WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
# GNU General Public License for more details. 
# 
#
######################################################################
# 
# Revision History:
#
# $Log: popsweeper.pl,v $
# Revision 0.7  2001/05/20 21:45:15  enneman
# cosmetic changes
#
# Revision 0.6  2001/04/16 20:17:40  enneman
# updated documentation
#
# Revision 0.5  2001/03/18 17:25:04  enneman
# limited mailbomb detection added
#
# Revision 0.4  2001/03/16 18:29:29  enneman
# cleanup
#
# Revision 0.3  2001/03/11 18:16:27  enneman
# changed the way buffering is turned off
#
# Revision 0.2  2001/03/11 17:01:41  enneman
# corrected extra newline in log file format
#
# Revision 0.1  2001/03/10 11:00:13  enneman
# First public release
#
##################################################################### 
# 
# disable buffering
#
$|++;
use Net::POP3;
use strict;
use Carp;
#
# Variabele declarations
#
my ($VERSION);
#
# Files used
#
my ($config_file);
my $log_file;
my $log_fh = undef;
#
# Per POP3 host 
#
my ($host, $user, $pass, $direct);
#
# For all hosts
#
my ($Max_Length, $debug);
#
# Program internal
#
my ($count,$delete,$spam_mail,$msgid,$exception);
my ($pop,$header_collapsed,$Msgid,$duplicate,$header);
#
# Arrays used
#
my (@POP3_Server, @User, @Password, @exceptionlist); 
my (@direct_adr, @Delete_spam, @header_lines);
my (@Messageids);
#
# Hashes used
#
my %hash;

####################################################
# Parse the configuration file 
####################################################
sub parse_configuratiefile 
{
    my ($config_file) = @_;
    #
    # Open the configuration file 
    #
    open(RCFILE, $config_file) || 
        writelog "Can't find the configuratie file %s", $config_file);
    #
    # Parse the file
    #
    while (<RCFILE>) 
    {
        next if ($_ =~ /^#/);
        if ($_ =~ /host=(.+)/i) 
        {
            push(@POP3_Server, $1);
        } 
        elsif ($_ =~ /user=(.+)/i) 
        {
            push(@User, $1);
        } 
        elsif ($_ =~ /pass=(.+)/i) 
        {
            push (@Password, $1);
        } 
        elsif ($_ =~ /delete=(.+)/i) 
        {
        push (@Delete_spam, $1);
        } 
        elsif ($_ =~ /direct=(.+)/i)
        {
                push (@direct_adr,$1);
        }
        elsif ($_ =~ /length=(.+)/i) 
        {
          $Max_Length = $1;
        } 
        elsif ($_ =~ /accept=(.+)/i) 
        {
          push (@exceptionlist, $1);
        }
        elsif ($_ =~ /debug=(.+)/i)
        {
            $debug = $1;
        }
    }
    close(RCFILE)||writelog("Can't close configuration file : %s",$config_file);
}

###################################################
# Make a connection to the pop server
###################################################
sub connect_pop 
{
    carp "Not enough arguments." unless(@_ == 3);
    my ($host, $user, $pass) = @_;
    $pop = Net::POP3->new($host, Timeout => 30)||
           writelog("Can't connect to %s",$host) && return;
    $pop->login($user, $pass)||writelog("Can't login %s on %s",$user,$host);
}

###################################################
# Delete the message  and log the complete header 
###################################################
sub delete_and_log_header
{
   my $log_message = shift; 
   writelog("%s",$log_message); 
   writelog("%s",join("",@{$header}));
   if ($delete eq "yes")
   {
       $pop->delete($msgid);
       writelog("Status : Deleted!\n","");
   } 
}

###################################################
# Write to the log file
###################################################
sub writelog
{
	my ($format, @args) = @_;
        unless(defined($log_fh))
	{
	    open($log_fh, ">>$log_file")||die "Can't open debug log!: $!\n"
        }
        printf $log_fh ($format, @args);
}

###################################################
# Search for SPAM in the mailqueue on the server 
###################################################
sub search_and_destroy 
{
    my $host=shift; 
    my $line;
    my $size;
    my $adres; 
    my $spam  = 0; 
    my $count = 0;
    my $MSGID = "MESSAGE-ID"; 
    #
    # Collect the list of headers ( nr + size) 
    #
    my $messages = $pop->list(); 
    #
    # for each pair (nr, size)...
    #
    while (($msgid, $size) = each (%$messages) ) 
    {
        $count++;
        writelog("---------------------------------------------\n",""); 
        writelog("Message nr: %s\n",$count); 
        #
        # Every mail is guilty until proven innocent
        # 
        $spam_mail = 1;  
        #
        # Collect the header for msgid. 
        # The reference to the array is placed in $header.
        #
        $header   = $pop->top($msgid);
        
        # 
        # In case not all fields in a message are filled,
        # initialize & zero out some of the hash values beforehand.
        #
        $hash{SENDER} ="";
        $hash{CC}     ="";
        $hash{SUBJECT}="";
        $hash{FROM}   ="";
        $hash{$MSGID} ="";
        $hash{TO}     =""; 
        #
        # Copy the array to a string,
        # and collapse fields with multiple lines to 1 line. 
        #
        $header_collapsed = join("",@{$header});
        $header_collapsed =~ s/\n[ \t.]/ /gs;
        # 
        # Split the string into an array again
        # (Ugh! this is _very_ inefficient)
        # 
        @header_lines = split /^/m, $header_collapsed;
        #
        # Subdivide the header into separate lines.
        #
        foreach $line (@header_lines) 
        {
            my($label, $value) = split /:\s/,    $line, 2;
            #
            # Change every label to uppercase
            #
            $label = uc $label;
            $hash{$label} = $value; 
        }
        #
        # Log the critical lines from the header to the log file
        # 
        writelog("From      : %s", $hash{FROM}||"\n"); 
        writelog("Subject   : %s", $hash{SUBJECT}||"\n");
        writelog("Diagnostic: ");
        
        #
        # Limited duplicate/mail bomb check
        # Check the Message-id of the message against previous messages
        # 
        
        $duplicate=0; 
        foreach $Msgid (@Messageids)
        {
            if ($hash{$MSGID} =~ /$Msgid/i)
            {
                $duplicate=1;
                delete_and_log_header("Duplicate or Mailbomb!\n"); 
                last;
            }
        }
        if ($duplicate == 1)
        {
               next;
        }
        else
        {
               #
               # Push the Message id on the array
               # 
               push(@Messageids,$hash{$MSGID});
        } 
        #
        # Check the size of the message
        # 
        if ($size >= $Max_Length) 
        {
           delete_and_log_header("> $Max_Length\n");
           next;    
        }
        
        #
        # Check on direct adressing ?
        # 
        if ($direct eq "yes" )
        {
             if (($hash{TO} =~ /$user\@/i) or
                 ($hash{CC} =~ /$user\@/i))
             {
                 $spam_mail = 0;
                 writelog("Directly adressed!\n",""); 
                 next; 
             }
        }

        foreach $exception (@exceptionlist) 
        {
             #
             # It is neccesary to look in the Subject line.
             #
             $exception =~ m/(^.*)\@/;
             $adres = $1 || "\0";
             if (($hash{SUBJECT} =~ /$adres/i)     or
                 ($hash{TO}      =~ /$exception/i) or
                 ($hash{SENDER}  =~ /$exception/i))
             {
                  $spam_mail = 0;
                  writelog("match on %s\n",$exception); 
                  last;
	     }
         }
        
         #
         # Log the header info
         #
         if ($spam_mail == 1)
         {
               $spam++;
               delete_and_log_header("SPAM!\n");
         }
    } 
    printf ("%s :\n %s messages\n%s spam\n", $host, $count, $spam); 
    writelog("Total on server : %s\n, Total Spam    : %s\n", $count, $spam);
    if ($delete eq "yes")  {writelog("Total deleted : %s\n",$spam);}  
    writelog("\n","");
}

#####################################################
# main program
#####################################################
#
# Default values 
#
$Max_Length     = 100000;
#
# SCCS/RCS entry
#
$VERSION        = do { my @r = (q$Revision: 0.7 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
#
#
#
my($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell);
print "Popsweeper version $VERSION\n";
#
# Determine the operating system. 
#
if ($^O eq "linux") 
{
   ($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell) = getpwuid($<);
   #
   # TODO: When running as root ==> drop the priviliges at once!
   #
   $config_file = "$dir/.popsweeperc";
   $log_file    = "$dir/popsweeper.log";
}
elsif ($^O eq "MSWin32")
{
   #
   # TODO: Location of Win32 configuration files is rather arbritrarily \
   #       chosen. Does anyone know a better method?
   #
   $config_file = "C:\\perl\\bin\\popsweeperc";
   $log_file    = "C:\\perl\\bin\\popsweeper.log";
}
else
{
    print ("Unknown OS %s\n", $^O);
    exit;
}

parse_configuratiefile($config_file);

writelog("\n************************************************************\n","");
writelog("Popsweeper version $VERSION starting at %s\n", scalar(localtime()));

foreach $host (@POP3_Server)
{
    #
    # Fetch user and password from configuration file
    # $direct and $delete are optional.
    #
    $pass   = shift (@Password) || writelog("Can't find password for %s",$host);
    $user   = shift (@User)     || writelog("Can't find user for %s",$host);
    $direct = shift (@direct_adr)|| "yes"; 
    $delete = shift (@Delete_spam)|| "no";
    
    writelog("Login as %s on %s \n", $user, $host);
    connect_pop($host, $user, $pass);
    search_and_destroy($host);
    $pop->quit();
    writelog("Connection closed at %s.\n", scalar(localtime())); 
}

close($log_fh) || writelog("Can't close logfile!: $_);
__END__

=head1 NAME

 popsweeper - Checks for spam on POP3 accounts  

=head1 SCRIPT CATEGORIES

 Mail

=head1 COPYRIGHT

 Copyright (C) 2000-2001 H.J. Enneman
 
 This program is free software; you can redistribute it and/or modify 
 it under the terms of the GNU General Public License as published by 
 the Free Software Foundation; either version 2 of the License, or 
 (at your option) any later version. 
 
 This program is distributed in the hope that it will be useful, 
 but WITHOUT ANY WARRANTY; without even the implied warranty of 
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
 GNU General Public License for more details. 

=head1 SYNOPSIS

 popsweeper.pl is a simple mail filter, which checks for spam
 mail on the POP server itself. Popsweeper can delete unwanted
 mail before you have to download it to your own computer.

=head1 DESCRIPTION

 popsweeper.pl works with a variant of the so-called "whitelist" 
 method. This means that popsweeper only allows mail that is:

 1. Directly addressed to you. Most spam mail is distributed via a
    mailinglist mechanism, which means that it isn't directly adressed
    to you. 
 2. Explicitly allowed in the configuration file. In this configuration
    file you can name all the mailinglists, domains and adresses from which
    you want to accept mail.
 3. Mail which is smaller than a size defined in the configuration file.
 4. Mail which has an unique message-id. Each e-mail message has an unique
    message-id. Because of this, popsweeper can do (limited) detection of
    duplicate mail and mailbombs. 
 
 The rest of the mail will be deleted, and only a copy of the header wil
 be preserved in the log file (popsweeper.log).

 Popsweeper wil _NOT_ get rid of all spam, but it will reduce the amount
 of spam that reaches you.
  
=head1 FILES

 popsweeper.pl uses the file .popsweeperc for configuration.

 #####################################
 # Example .popsweeperc file 
 #
 # host/user/password/direct/delete
 #
 # host   -> DNS name of pop3 host
 # user   -> name of useraccount on pop3 host
 # pass   -> password for useraccount on pop3 host
 # direct -> check for direct adressing (yes/no)
 # delete -> delete the spam (yes/no) 
 # length -> maximum size of mail
 ##################################### 
 # host 1
 #
 host=aaa.bbb.ccc
 user=humpty
 pass=skdfj01k
 direct=yes
 delete=no
 #
 # host 2
 #
 host=xxx.yyy.zzz
 user=dumpty
 pass=23xs929
 direct=no
 delete=yes
 ####################################
 #
 # Maximal length of mail
 #
 length=100000
 ####################################
 #
 # WHITELIST
 #
 # Accept the following lists
 # and/or adresses
 #
 # These can be partial or complete
 # adresses.
 #
 accept=members@gmx.net
 accept=sysinternals@egroups.com
 accept=announce@
 accept=samba-ntdom@
 accept=wwwoffle-announce@gedanken.demon.co.uk
 accept=perl-update@pepper.oreillynet.com
 accept=security@
 accept=popsweeper@

=head1 CAVEATS/WARNINGS

 This script can lead to loss of data. 
 Use at your own risk!

 This script only carries out checks on size and
 the mail headers. Not on the body of the email!

=head1 ENVIRONMENT

 Under UNIX, popsweeper uses getpwent to find 
 the configuration file .popsweeperc

=head1 PREREQUISITES

 This script requires Net::POP3 and the Carp modules.

=head1 HISTORY
 
 Popsweeper was designed to be a noninteractive script which is to be called 
 from ip-up.

 Popsweeper was originally created to get rid of a very annoying periodical
 mailing from a cinema exploitant. Instead of plain text files with film
 schedules large .doc files were send. It was not possible to unsubscribe
 from this mailinglist. Not wanting to download large email messages on
 a slow modem line, a script was devised a method to get rid of these un-
 wanted messages.
 Popsweeper's first incarnation only dealt with this one annoyance but it
 (quickly) grew to deal with other spam.

 
 Thanks to:
 The comp.lang.perl.misc crowd, both for asking and answering questions.

=head1 REVISION

$Id: popsweeper.pl,v 0.7 2001/05/20 21:45:15 enneman Exp enneman $

=cut
