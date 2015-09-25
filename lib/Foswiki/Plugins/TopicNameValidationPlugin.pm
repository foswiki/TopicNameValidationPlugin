# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2015 MichaelDaum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TopicNameValidationPlugin;

use strict;
use warnings;

use Foswiki::Func();
use Foswiki::Plugins();
use Foswiki::OopsException();

our $VERSION = '1.20';
our $RELEASE = '6 May 2013';
our $SHORTDESCRIPTION = 'Control naming of topics';
our $NO_PREFS_IN_TOPIC = 1;

our $baseWeb;
our $baseTopic;
our @ruleSet;
our $doneInit = 0;

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  return unless DEBUG;
  print STDERR "- TopicNameValidationPlugin - " . $_[0] . "\n";
  #Foswiki::Func::writeDebug("- TopicNameValidationPlugin - $_[0]");
}


###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  $doneInit = 0;
  @ruleSet = ();

  return 1;
}

###############################################################################
sub doInit {

  return if $doneInit;
  $doneInit = 1;
  
  writeDebug("called doInit()");

  my $systemWeb = $Foswiki::cfg{SystemWebName};
  my $ruleSetTopics = Foswiki::Func::getPreferencesFlag("TOPICVALIDATION_PLUGIN_RULESET") 
    || "$systemWeb.TopicNameValidationPlugin, System.TopicNameValidationPlugin";

  # read rule sets
  foreach my $webTopic (split(/\s*,\s*/, $ruleSetTopics)) {

    # get topic name
    my ($ruleSetWeb, $ruleSetTopic) = Foswiki::Func::normalizeWebTopicName($baseWeb, $webTopic);
    unless (Foswiki::Func::topicExists($ruleSetWeb, $ruleSetTopic)) {
      my $msg = "ruleset topic '$webTopic' not found";
      writeDebug($msg);
      Foswiki::Func::writeWarning($msg);
      next;
    }

    # read rules
    my ($meta, $text) = Foswiki::Func::readTopic($ruleSetWeb, $ruleSetTopic);
    foreach my $line (split /\n/, $text) {
      if ($line =~ /^\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$/) {
        writeDebug("line=$line");
        next if $1 =~ /^\*.*\*$/o;
        next if $3 =~ /disabled/;
        my $isAllowed = ($3 =~ /allowed/)?1:0;
        # add to set
        push @ruleSet, {
          pattern => $1,
          error => $2,
          isAllowed => $isAllowed,
        };
        writeDebug("found pattern='$1', error='$2', isAllowed=$isAllowed");
      }
    }
  }
}

###############################################################################
sub checkRules {
  my ($action, $text, $topic, $web, $meta) = @_;

  doInit();

  $web =~ s/\//\./go;
  my $webTopicName = "$web.$topic";
  foreach my $rule (@ruleSet) {
    my $pattern = $rule->{pattern};

    if ($webTopicName =~ /$pattern/) {
      #writeDebug("$webTopicName matches '$pattern'");
      unless ($rule->{isAllowed}) {
        throw Foswiki::OopsException( 
          'topicname',
          def => $action,
          web => $web,
          topic => $topic,
          params => [ $action, $webTopicName, $rule->{error} ] );
      }
      return;
    }
  }
}

###############################################################################
sub beforeSaveHandler { 
  checkRules('save', @_); 
}

###############################################################################
sub beforeEditHandler { 
  checkRules('edit', @_); 
}

1;
