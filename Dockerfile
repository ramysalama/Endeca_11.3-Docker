FROM oraclelinux:7

ENV src_folder /sde/endeca_installers

#Create Endeca user & group
RUN /usr/sbin/groupadd endeca_dev 
RUN /usr/sbin/useradd -G endeca_dev endeca
RUN echo endeca:endeca | chpasswd

#create SDE folder & set ownership to Endeca user
RUN mkdir /sde
RUN chown -R endeca:endeca_dev /sde


#Install unzip
RUN yum -y install unzip

#Copy installers and config files
COPY . $src_folder
WORKDIR $src_folder

#Copy Copying start/stop scripts
COPY config/start-endeca.sh /sde
COPY config/shutdown-endeca.sh /sde

#Unzip installers
RUN unzip $src_folder/01_MDEX/V861206-01.zip -d $src_folder/01_MDEX
RUN unzip $src_folder/02_PS/V861203-01.zip -d $src_folder/02_PS
RUN unzip $src_folder/03_TAF/V861215-01.zip -d $src_folder/03_TAF
RUN unzip $src_folder/04_CAS/V861198-01.zip -d $src_folder/04_CAS

#Fix Executable Permissions
RUN chmod -R 755 $src_folder/01_MDEX/OCmdex11.3.0-Linux64_1186050.bin $src_folder/02_PS/OCplatformservices11.3.0-Linux64.bin $src_folder/03_TAF/cd $src_folder/04_CAS/OCcas11.3.0-Linux64.bin
#RUN chmod -R 755 $src_folder/02_PS/OCplatformservices11.3.0-Linux64.bin
#RUN chmod -R 755 $src_folder/03_TAF/cd
#RUN chmod -R 755 $src_folder/04_CAS/OCcas11.3.0-Linux64.bin

#Switch to Endeca user
USER endeca

#Installation
#Installing MDEX
WORKDIR $src_folder/01_MDEX/
RUN ./OCmdex11.3.0-Linux64_1186050.bin -i silent -f $src_folder/config/mdex_response.properties
RUN source /sde/endeca/MDEX/11.3.0/mdex_setup_sh.ini

#Installing Platform-and-services
WORKDIR $src_folder/02_PS/
RUN ./OCplatformservices11.3.0-Linux64.bin -i silent -f $src_folder/config/ps_response.properties
COPY config/eaccmd.properties /sde/endeca/PlatformServices/workspace/conf
RUN source /sde/endeca/PlatformServices/workspace/setup/installer_sh.ini

#Installing Tools and framework
COPY config/silent_response.rsp $src_folder/03_TAF/cd/Disk1/install
WORKDIR $src_folder/03_TAF/cd/Disk1/install
RUN  ./silent_install.sh $src_folder/03_TAF/cd/Disk1/install/silent_response.rsp ToolsAndFrameworks /sde/endeca/ToolsAndFrameworks
COPY config/webstudio.properties /sde/endeca/ToolsAndFrameworks/11.3.0/server/workspace/conf
RUN export ENDECA_TOOLS_ROOT=/sde/endeca/ToolsAndFrameworks/11.3.0
RUN export ENDECA_TOOLS_CONF=/sde/endeca/ToolsAndFrameworks/11.3.0/server/workspace

#CAS
WORKDIR $src_folder/04_CAS/
RUN ./OCcas11.3.0-Linux64.bin -i silent -f $src_folder/config/cas_response.properties
COPY config/commandline.properties /sde/endeca/CAS/workspace/conf
RUN export CAS_ROOT=/sde/endeca/CAS/11.3.0
RUN sed -i 's/^\(com.endeca.casconsole.cas.server=\).*/\1localhost/' /sde/endeca/ToolsAndFrameworks/11.3.0/server/workspace/conf/casconsole.properties

#Updating bash profile
RUN echo 'source /sde/endeca/MDEX/11.3.0/mdex_setup_sh.ini' >>~/.bash_profile
RUN echo 'source /sde/endeca/PlatformServices/workspace/setup/installer_sh.ini' >>~/.bash_profile
RUN echo 'export ENDECA_TOOLS_ROOT=/sde/endeca/ToolsAndFrameworks/11.3.0' >>~/.bash_profile
RUN echo 'export ENDECA_TOOLS_CONF=/sde/endeca/ToolsAndFrameworks/11.3.0/server/wor kspace' >>~/.bash_profile
RUN echo 'export CAS_ROOT=/sde/endeca/CAS/11.3.0' >>~/.bash_profile

#Fix permissions
USER root
RUN chmod -R 755 /sde/endeca

#Delete installers
#WORKDIR /sde
RUN rm -rf $src_folder

#Creating volume for data persistence
VOLUME /sde

#Network config
EXPOSE 8006 8500 8506

#Start up Endeca
#USER endeca
#CMD ["/bin/sh","/sde/start-endeca.sh"]

