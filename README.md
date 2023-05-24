# WalletanoNodes

This script will periodically pull https://api.walletano.com/ and will proceed with payments that you start on your self-custodial walletano.com wallet.

Dependencies: perl-JSON  
To install dependencies run as root:
> apt-get install libjson-rpc-perl

## Installation

You should add a separate user (walletano) and clone the git repo with this user to /home/walletano/.
> adduser walletano  
> su walletano  
> cd /home/walletano/  
> git clone git@github.com:Walletano/WalletanoNodes.git

This will create a separate directory (WalletanoNodes) to /home/walletano/.

### Prerequisites:
1. You need to sign in with your node to Walletano.com and create a self-custodial wallet.
2. You need to provide Walletano with RPC access to your node. Go to Walletano.com, and create a Self-Custodial wallet, follow the steps to provide read only and invoice creation macaroons to Walletano. Remember, with these rights, Walletano can not touch your funds.  
Run walletano_initiatepayments.pl on your lnd node to proceed with payments started on Walletano.  
Rename sample_config.pl to config.pl and adjust config.pl with your own setup.  

To make sure walletano_initpayments.pl is always running, you need to add a systemd service. You can find a sample service file (walletano_initiatepayments.service) on the repo.

Open a text editor and create a new file with the .service extension. For example, /etc/systemd/system/walletano_initiatepayments.service. Paste the contents of walletano_initiatepayments.service file to the newly created file. Then run:

> sudo systemctl daemon-reload  
> sudo systemctl start walletano_initiatepayments.service  
> sudo systemctl enable walletano_initiatepayments.service  

Now the Perl script will run at boot and be automatically restarted if it stops for any reason. To check the status of the service, use the following command:

> sudo systemctl enable walletano_initiatepayments.service

You can also check the output of the script by running:

> tail -f /home/walletano/WalletanoNodes/logs/initiatepayments.log

## Optional steps to make the payments almost realtime 

Create a new user:
> adduser wlt_hook  
> passwd -l wlt_hook  
> su wlt_hook  
> mkdir /home/wlt_hook/notifier  
> chmod -R 777 /home/wlt_hook/notifier/  

Add walletano server's public SSH key to this user:

> test -d ~/.ssh || mkdir ~/.ssh && chmod 700 ~/.ssh && test -f ~/.ssh/authorized_keys && grep -qxF "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDDBuKjFgwH9mZZirTyiU2aXPmdSdYEwAYvWEutuqTMYFCPQnjM+TWJh/y06oXvEPkmF5E46WIBgSeM5W+lQYxAK21Fqelcr6e2f6Epbxe/U5ehdsjQD9myiLWhhRll2rKEO0PRvzx1FgDcoTvGi9xUfUPdN9IWeb7ttEpqoiL7jiFo4bO32DUqPPKSFynnwNfF/4H8KkW16sgrL0+PEgDd2lB9kLGecpkCP+QMANaIqlhagMO0OriZBwkLUlQAY2ZEoPzpQSuWAO2mE+5JlJBJRyVElKthxnuk5K9hx0JqN1jbki6WzYbuQ/44TzCC3bF6JnQfwBlpRL89m6wksCo/ walletano" ~/.ssh/authorized_keys || echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDDBuKjFgwH9mZZirTyiU2aXPmdSdYEwAYvWEutuqTMYFCPQnjM+TWJh/y06oXvEPkmF5E46WIBgSeM5W+lQYxAK21Fqelcr6e2f6Epbxe/U5ehdsjQD9myiLWhhRll2rKEO0PRvzx1FgDcoTvGi9xUfUPdN9IWeb7ttEpqoiL7jiFo4bO32DUqPPKSFynnwNfF/4H8KkW16sgrL0+PEgDd2lB9kLGecpkCP+QMANaIqlhagMO0OriZBwkLUlQAY2ZEoPzpQSuWAO2mE+5JlJBJRyVElKthxnuk5K9hx0JqN1jbki6WzYbuQ/44TzCC3bF6JnQfwBlpRL89m6wksCo/ walletano" >> ~/.ssh/authorized_keys

This will allow Walletano (the service and / or our servers) to SCP / SSH to your server and push the paymentwatcher file to /home/wlt_hook/notifier/paymentwatcher. As soon as you initiate a payment via Walletano from your self-custodial wallet, we will push an empty file (paymentwatcher) to your server. This file is monitored by walletano_initiatepayments.pl and as soon as it appears on your node, it will automatically access your payments URL from Walletano and pull the payment that you want to make.

Remember, Walletano (the service and / or our servers) will only have the same permissions as you provide to wlt_hook user, we only need to have write access to the notifier folder. Also, the notifier folder should have 777 rights, so that your local walletano user (the user that is running the walletano_initiatepayments.pl) can delete the paymentwatcher file as soon as the payment is initiated on your node. 

## Security of your funds / funds on your node

If you want to make sure Walletano will never ask your node to make a payment that you have not initiated, you should set a Node Secret at Walletano wallet and add the same secret to your node's config.pm. This secret will never reach Walletano servers, it is stored only locally on your device and on your node for verification.  
When you initiate a payment from a self-custodial wallet on Walletano, we will hash the "payment_request" you would like to pay (the unique identifier of the invoice you want to pay) and your "node secret" on your device (locally, the node secret does never reach our servers), we call this "verifyhash". When you confirm payment, this "verifyhash" and the "payment_request" is sent to Walletano, and Walletano will send the "verifyhash" and the "payment_request" to your node. On your node, the walletano-initiatepayments.pl script:  
1) will notice a new payment that should be initiated  
2) hash the received "payment_secret" and your locally saved "secret" - we call it "compared_hash"  
3) compare the received "verifyhash" with the created "compared_hash", and  
4) if the hashes are identical, your node will proceed with the payment, if not, your node will not proceed the payment.
