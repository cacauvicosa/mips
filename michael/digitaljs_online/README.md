#MIPS and RISCV Verilog implementations

How to install tools

- Install NodeJS: https://nodejs.org/en/

- Install yarn: https://yarnpkg.com/

- Install Yosys: http://www.clifford.at/yosys/download.html

##Example Install Ubuntu 18.04 LTS

```
	# clone the repository
	git clone https://github.com/cacauvicosa/mips
	cd mips/michael/digitaljs_online/

	# Install Nodejs
	sudo snap install node --classic --channel=12
	
	# Install yarn
	curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
	echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
	sudo apt update && sudo apt install yarn
	
	# Install yosys
	sudo apt-get install build-essential clang bison flex libreadline-dev gawk tcl-dev libffi-dev graphviz xdot pkg-config python3 libboost-system-dev libboost-python-dev libboost-filesystem-dev zlib1g-dev
	unzip yosys-yosys-0.8.zip
	cd yosys-yosys-0.8
	make
	sudo make install
```

##How to execute on localhost 

```
	yarn server # terminal 1
	yarn client # terminal 2
```


