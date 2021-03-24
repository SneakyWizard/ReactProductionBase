
	- A production react and node server using pm2.

	Usage:

		./create-react-node-pm2.pl -option <value>
	
	Options:
	
		-app-name    [manditory] string
		-react-port  [optional] int defaults to 5000
		-server-port [optional] int defaults to 3000
		-dev-mode    [optional] flag defaults to production mode.

		(dev-mode stuff)
		(Later change ecosystem.config.js args to 'run start' instead of 'run dev' for prod use)
		(pm2 restart all && pm2 ls)

	Examples: 

		1) ./create-react-node-pm2.pl -app-name test 
		2) ./create-react-node-pm2.pl -app-name test -react-port 5001 -dev-mode
		3) ./create-react-node-pm2.pl -app-name test -react-port 5001 -server-port 3001
