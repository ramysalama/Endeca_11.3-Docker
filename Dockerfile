FROM oraclelinux:7

ENV install_folder /OGS

ENV src_folder $install_folder/endeca_installers

#Create Endeca user & group , create $install_folder folder & set ownership to Endeca user, Install unzip & libaio
RUN useradd -m -s /bin/bash endeca && \
 echo endeca:endeca | chpasswd && \
 mkdir $install_folder && \
 chown -R endeca:endeca $install_folder && \
 yum -y install unzip libaio

#Copy installers and config files
COPY --chown=endeca:endeca . $src_folder

#Copy Copying start/stop scripts
COPY --chown=endeca:endeca config/start-endeca.sh $install_folder
COPY --chown=endeca:endeca config/shutdown-endeca.sh $install_folder

#Unzip installers, Fix Executable Permissions
RUN unzip $src_folder/01_MDEX/V861206-01.zip -d $src_folder/01_MDEX && \
 unzip $src_folder/02_PS/V861203-01.zip -d $src_folder/02_PS && \
 unzip $src_folder/03_TAF/V861215-01.zip -d $src_folder/03_TAF && \
 unzip $src_folder/04_CAS/V861198-01.zip -d $src_folder/04_CAS && \
 chmod -R 755 $src_folder/01_MDEX/OCmdex11.3.0-Linux64_1186050.bin $src_folder/02_PS/OCplatformservices11.3.0-Linux64.bin $src_folder/03_TAF/cd $src_folder/04_CAS/OCcas11.3.0-Linux64.bin

#Switch to Endeca user
USER endeca

COPY config/silent_response.rsp $src_folder/03_TAF/cd/Disk1/install

#Installation
#Installing MDEX, Platform-and-services, Tools and framework, CAS
RUN $src_folder/01_MDEX/OCmdex11.3.0-Linux64_1186050.bin -i silent -f $src_folder/config/mdex_response.properties && \
 source $install_folder/endeca/MDEX/11.3.0/mdex_setup_sh.ini && \
 $src_folder/02_PS/OCplatformservices11.3.0-Linux64.bin -i silent -f $src_folder/config/ps_response.properties && \
 source $install_folder/endeca/PlatformServices/workspace/setup/installer_sh.ini && \
 $src_folder/03_TAF/cd/Disk1/install/silent_install.sh $src_folder/03_TAF/cd/Disk1/install/silent_response.rsp ToolsAndFrameworks $install_folder/endeca/ToolsAndFrameworks && \
 $src_folder/04_CAS/OCcas11.3.0-Linux64.bin -i silent -f $src_folder/config/cas_response.properties && \
 sed -i 's/^\(com.endeca.casconsole.cas.server=\).*/\1localhost/' $install_folder/endeca/ToolsAndFrameworks/11.3.0/server/workspace/conf/casconsole.properties

#Copy configurations
COPY --chown=endeca:endeca config/eaccmd.properties $install_folder/endeca/PlatformServices/workspace/conf
COPY --chown=endeca:endeca config/webstudio.properties $install_folder/endeca/ToolsAndFrameworks/11.3.0/server/workspace/conf 
COPY --chown=endeca:endeca config/commandline.properties $install_folder/endeca/CAS/workspace/conf/

#Updating bash profile
USER root
RUN cp $install_folder/endeca/MDEX/11.3.0/mdex_setup_sh.ini /etc/profile.d/mdex_setup.sh && \
 cp $install_folder/endeca/PlatformServices/workspace/setup/installer_sh.ini /etc/profile.d/ps_setup.sh && \
 cat /etc/profile.d/mdex_setup.sh >> /etc/profile.d/ps_setup.sh && \
 chmod 666 /etc/profile.d/ps_setup.sh && \
 echo "export ENDECA_TOOLS_ROOT=/OGS/endeca/ToolsAndFrameworks/11.3.0" >>/etc/profile.d/taf_setup.sh && \
 echo "export ENDECA_TOOLS_CONF=/OGS/endeca/ToolsAndFrameworks/11.3.0/server/workspace" >>/etc/profile.d/taf_setup.sh && \
 echo "export CAS_ROOT=/OGS/endeca/CAS/11.3.0" >>/etc/profile.d/cas_setup.sh

#Fix permissions & delete installers
WORKDIR $install_folder
RUN chmod -R 755 $install_folder/endeca && \
	chown -R endeca:endeca $install_folder && \
	rm -rf $src_folder

#Volume to be created from the child image not base image
#VOLUME $install_folder

#Network config
EXPOSE 8006 8500 8506 8888 15000 15001 15010

#Start up Endeca
#USER endeca
#CMD ["/bin/bash","$install_folder/start-endeca.sh"]

