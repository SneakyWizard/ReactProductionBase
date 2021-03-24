#!/usr/bin/perl -w 

use strict;
use Getopt::Long;
use File::Slurp qw(write_file);

my $npm  = `which npm`;
my $node = `which node`;

chomp $npm;
chomp $node;

if ( !$npm || !$node ) { 
	die "INSTALL NodeJS AND npm OR ADJUST YOUR \$PATH. $!\n";
}

my $remove      = '';
my $nostart     = '';
my $dev_mode    = '';
my $app_name    = '';
my $react_port  = 5000;
my $server_port = 3000;

GetOptions(
	"app-name=s"    => \$app_name,
	"react-port=i"  => \$react_port,
	"server-port=i" => \$server_port,
	"dev-mode"      => \$dev_mode,
	"nostart"       => \$nostart,
	"remove"        => \$remove
);

# Usage.
if ( !$remove && !$app_name ) {
	die "
	- A production react and node server using pm2.

	Usage:

		$0 -option <value>
	
	Options:
	
		-app-name    [REQUIRED] string
		-react-port  [Optional] int defaults to $react_port.
		-server-port [Optional] int defaults to $server_port.
		-dev-mode    [Optional] flag defaults to production mode.
		-nostart     [Optional] flag which enables not running pm2 start.
		-remove      [Optional] flag which removes the pm2 services.

		(dev-mode stuff)
		(Later change ecosystem.config.js args to 'run start' instead of 'run dev' for prod use)
		(pm2 restart all && pm2 ls)

	Examples: 

		1) ./create-react-node-pm2.pl -app-name test 
		2) ./create-react-node-pm2.pl -app-name test -react-port 5001 -dev-mode
		3) ./create-react-node-pm2.pl -app-name test -react-port 5001 -server-port 3001
	$!\n";
}

if ( -d $app_name ) { 
	die "app_name $app_name directory already exists! $!\n";
}

if ( $remove ) {

	# Check the pm2 pid.
	my $pid = `cat $ENV{HOME}/.pm2/pm2.pid`;
	chomp $pid;

	if ( $pid ) {

		system( "pm2 status" );
		print "pm2 is running on $pid.  Continue? (y/n): ";

		my $continue = <STDIN>;
		chomp $continue;

		if ( $continue =~ /y/i ) {
			system ( 'pm2 del react' );
			system ( 'pm2 del server' );
		}
	}

	die "$!\n";
}

# Install the create react script.
system ( 'npm install -g create-react-app' );
die "Failed to install create-react-app" if $? == -1;

# Create the app_name.
system ( "create-react-app $app_name" );
die "Failed to run create-react-app" if $? == -1;

chdir $app_name;

# Build react for production.
system ( "npm run build" );
die "Failed to npm run build" if $? == -1;

# Install pm2 fork based server.
system ( "npm install pm2 -g" );
die "Failed to npm install pm2" if $? == -1;

# Some npm modules.
system ( "npm install node-env-run nodemon npm-run-all express-pino-logger pino-colada --save-dev" );
die "Failed dependancies" if $? == -1;

my $react_args = $dev_mode ? "run dev" : "run start";

# The pm2 ecosystem.
# pm2 start echosystem
# pm2 stop echosystem
# pm2 ps
my $ecosystem = qq~
module.exports = {
 apps : [
    {
      name      : 'react',
      script    : 'npm',
      args      : '$react_args',
      env_production : {
        NODE_ENV: 'production'
      }
    },
    {
      name      : 'server',
      script    : 'npm',
      args      : 'run server',
      env_production : {
        NODE_ENV: 'production'
      }
    }
  ],
};~;

write_file( 'ecosystem.config.js', $ecosystem );
system ( "ls -alF ecosystem.config.js" );

# The index.js node server.  This will change to how your server ought to be.
my $index_js = qq~
const pino       = require('express-pino-logger')();
const express    = require('express');
const bodyParser = require('body-parser');

const app = express();
app.use( bodyParser.urlencoded( { extended: false } ) );
app.use( pino );

app.get( '/api/greeting', ( req, res ) => {
	const name = req.query.name || 'World';
	res.setHeader( 'Content-Type', 'application/json' );
	res.send( JSON.stringify( { greeting: `Hello! \${name}` } ) );
} );

app.listen( $server_port, () =>
	console.log( 'Express server is running on http://localhost:$server_port' )
);
~;

# Create the index.js.
mkdir 'server';
write_file( 'server/index.js', $index_js );
system ( "ls -alF server/index.js" );

# The package.json for react, node, pm2.
my $package_json = qq~
{
  "name": "$app_name",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "\@testing-library/jest-dom": "^4.2.4",
    "\@testing-library/react": "^9.5.0",
    "\@testing-library/user-event": "^7.2.1",
    "pm2": "^4.4.1",
    "react": "^16.13.1",
    "react-dom": "^16.13.1",
    "react-scripts": "3.4.3",
    "server": "^1.0.30"
  },
  "scripts": {
    "start": "PORT=$react_port serve -s build",
    "dev": "PORT=$react_port react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test --env=jsdom",
    "eject": "react-scripts eject",
    "server": "node-env-run server --exec nodemon | pino-colada"
  },
  "eslintConfig": {
    "extends": "react-app"
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "devDependencies": {
    "express-pino-logger": "^5.0.0",
    "node-env-run": "^4.0.1",
    "nodemon": "^2.0.4",
    "npm-run-all": "^4.1.5",
    "pino-colada": "^2.1.0"
  },
  "proxy": "http://localhost:$server_port"
}~;

# Copy the package.json and start pm2.
write_file( 'package.json', $package_json );
system ( "touch .env" );
system ( "ls -alF package.json" );

if ( $nostart ) {
	print "Run - \"cd $app_name && pm2 start ecosystem.config.js\" to start.\n";
} else {
	system ( "pm2 start ecosystem.config.js" );

	# For the env registration is slow.
	sleep 5;

	# Check to see if the server is actually listening.
	my $server_start = `nc -w1 -v localhost $server_port 2>&1`;
	my $react_start  = `nc -w1 -v localhost $react_port 2>&1`;

	chomp $server_start;
	chomp $react_start;

	if ( $server_start =~ /succeeded/i && $react_start =~ /succeeded/i ) { 
		print "Servers are running.\ncd $app_name\npm2 ps\npm2 stop ecosystem\npm2 start ecosystem\n";
	} else { 
		die "-> COULD NOT START:\n$server_start\n$react_start - \nRUN:  cd $app_name && pm2 logs$!\n";
	}
}
