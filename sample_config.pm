#!/usr/bin/perl

$apikey = ""; # your walletano api key
$lncli_comd = "docker exec lnd lncli"; # "lncli" or "docker exec lnd lncli" if running umbrel
$maxppm = "3000"; #ppm
$maxbase = "1"; #basefee in satoshi
$minapirequesttime = 300; #crawl the server to check if new payments need to be initiated at least once in $minapirequesttime seconds
$pubkey = "032...."; # your node pubkey, get it with lncli getinfo 

$watcherfiledir = "/home/wlt_hook/notifier";
$watcherfilename = "/home/wlt_hook/notifier/paymentwatcher";
# whenever a new payment needs to be made by this node, we will scp this file to the location specified above, this will trigger the script to overwrite for a few seconds the $minapirequesttime so payments will be initiated much faster

$nodesecret = "mysecret"; #to make sure you only send out payments from your node by providing a password at payment
# when you'll initiate a payment from your walletano self custodial wallet, we will hash the lightning invoice with your secret and send the hash to your node so you can verify that it is indeed you that tries to make a payment
# secret is not known by Walletano, Walletano servers will only receive the hash of your invoice and your secret, hashing is made on your client only (Walletano app or browser).

$sleeptime = 0.2; # seconds
# The lower this number, the faster your payments will proceed.
# Warning! Very low numbers (0.01 for example) can cause high CPU usage!

$database = "walletano";
$dbserver = "localhost";
$dbport = "3306";
$dbuser = "pwro";
$dbpass = "password";