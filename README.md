### vyos-docker
VyOs Docker image build tool.

Inspired by higebu [higebu/vyos](https://www.higebu.com/blog/2014/12/09/vyos-docker-image/)

#### How to build vyos docker image

```
git clone https://github.com/thanhledev/vyos-docker.git
sudo chmod +x ./build_vyos.sh
./build_vyos.sh <docker_username> <vyos_url_download>
```
For example:
`./build_vyos.sh thanhledev https://downloads.vyos.io/?dir=release/legacy/1.1.8`

The directories of all VyOS ISO images can be found here: https://downloads.vyos.io/

#### How to use the new VyOS docker image in Kathara
1. Create the vyatta node in Kathara
  ```
  sudo kathara vstart -n vyatta --eth 0:A 1:B 2:C 3:D 4:E --privileged --shell vbash
  ```
  **Remember to run kathara with sudo as we need to run the vyatta docker container with privileged**

2. Login to the vyatta node
  ```
  kathara connect -v vyatta --shell vbash
  ```

3. How to configure the vyatta
  - We perform another login inside the node terminal:
  ```
  $ login
  ```
  with the following credentials: vyos/vyos
  - Run the vyos commands such as:
    - show configuration/interfaces...
    - configure
    - set interfaces ethernet eth0 address dhcp/static (172.17.0.2/16)
    - commit
    - exit
 
 At the moment, the VyOS image support *at most* 5 interfaces eth0-eth4.
