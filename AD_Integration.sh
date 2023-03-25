#/bin/bash

yum install -y samba-client samba-winbind samba-winbind-clients


currentTimestamp=`date +%y-%m-%d-%H:%M:%S`
prefix='/etc'

echo "Configure smb"
smbConfFile="$prefix/samba/smb.conf"
smbConfFileBackup=$smbConfFile.$currentTimestamp.bak
if [ -f "$smbConfFile" ]; then
    echo backup $smbConfFile to $smbConfFileBackup
    cp $smbConfFile $smbConfFileBackup
fi
cat > "$smbConfFile" << EOF
[global] 
    security = ADS
    workgroup = MCB
    realm = MCB.NET.MM
    server string = Samba Server
    winbind separator = +

    idmap config * : backend = tdb
    idmap config * : range = 1000-20000

    template shell = /bin/bash
EOF

echo "Join the domain."
systemctl stop winbind > null
net ads join -U administrator

if [ $? -eq 0 ]; then
    echo "Start winbind and enable it on boot."
    systemctl start winbind
    systemctl enable winbind


    echo "Configure the NSS and PAM stack."
    nsswitchConfFile="$prefix/nsswitch.conf"
    nsswitchConfFileBackup=$nsswitchConfFile.$currentTimestamp.bak
    if [ -f "$nsswitchConfFile" ]; then
        cp $nsswitchConfFile $nsswitchConfFileBackup
    fi

    pamConfFile="$prefix/pam.d/system-auth"
    pamConfFileBackup=$pamConfFile.$currentTimestamp.bak
    if [ -f "$pamConfFile" ]; then
        cp $pamConfFile $pamConfFileBackup
    fi


    authConfFile="$prefix/sysconfig/authconfig"
    authConfFileBackup=$authConfFile.$currentTimestamp.bak
    if [ -f "$authConfFile" ]; then
        cp $authConfFile $authConfFileBackup
    fi

    sed -i 's/FORCELEGACY=no/FORCELEGACY=yes/' /etc/sysconfig/authconfig
    authconfig --enablewinbindauth --enablewinbind --enablemkhomedir --enableforcelegacy --update  > null

    echo "Verify the the system can talk to Active Directory."
    wbinfo -t
else
    echo "---------------------------------------------------"
    echo "Failed to join domain. Before running the script,"
    echo "- Ensure that the system time between the Domain Controller and RHEL server are synchronized."
    echo "- Ensure that /etc/resolv.conf is set to a DNS server that can resolve your AD DNS zones, and that the search domain is set to the AD DNS domain."
fi