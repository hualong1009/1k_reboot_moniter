#!/usr/local/bin/python3
'''
	Auther: Hansen
	Description: This script make ini file
'''
#-*-coding:utf-8-*-
#coding=utf-8
import os,os.path,time,shutil

state_path_ongoing="/var/ftp/pub/on-going/"
state_path_completed="/var/ftp/pub/completed/"
state_ini="/var/ftp/pub/status.ini"
state_completed_ini="/var/ftp/pub/status_completed.ini"
state_path_ini="/var/ftp/pub/"
stat_ini_swp="/var/ftp/pub/status_swap.ini"

def get_config(state_path,state_file):
	os.chdir(state_path)
	config=open(state_file,'w')
	for path in os.listdir(state_path):
		if os.path.isdir(state_path+path) and os.path.isfile(state_path+path+'/count'):
			os.chdir(state_path+path)
			file=open('count','r')
			eachline=file.read()
			if eachline == '0':
				file.close()
				return(1)
			if state_path == state_path_completed:
				config.write('['+path+']\n'+'count='+eachline)
			else:
				config.write('['+path[4:16]+']\n'+'count='+eachline)
			file.close()
			file=open('ipmi_lan.log','r')
			for eachline in file:
				if eachline.startswith('IP Address'):
					ip=eachline.split(': ')[1]
			file.close()			
			config.write('bmc_IP='+ip)
			try:
				file=open('1.testinfo/test_info.txt','r')
			except FileNotFoundError:
				ip="Unknown\n"
				tester="Unknown\n"
				bmc_ver="Unknown\n"
				bios_ver="Unknown\n"
			else:
				for eachline in file:
					if eachline.startswith('BMC Ver.'):
						bmc_ver=eachline.split(':')[1]
					if eachline.startswith('BIOS Ver.'):
						bios_ver=eachline.split(':')[1]
					if eachline.startswith('OS IP Addr.'):
						ip=eachline.split(':')[1]
					if eachline.startswith('Tester Name'):
						tester=eachline.split(':')[1]
			file.close()			
			with open('ipmi_bmc.log','r') as file:
				file_lines=file.readlines()
				bmc_ver=bmc_ver.strip()+' '+file_lines[-1].strip()+'\n'
			config.write('10G_IP='+ip+'tester='+tester+'bmc_version='+bmc_ver+'bios_version='+bios_ver)
			config.write('folder_name='+path+'\n')
			try:
				file=open('1.testinfo/1kreboot_info.txt','r')
			except FileNotFoundError:
				mode="Unknown\n"
			else:
				for eachline in file:
					if eachline.startswith('# cycle:'):
						mode=eachline.split(':')[1].strip()
					if eachline.startswith('# power_cycle:'):
						PDU_port=eachline.split(' ')[4].strip()+'\n'
				mode_port=mode+' '+PDU_port
					
			config.write('mode='+mode_port)
			file.close()
	config.close()
def convert(file_name):
	file=open(file_name,'rb')
	file_line=file.read()
	file_new_line=file_line.replace(b'\n',b'\r\n')
	file.close()
	file=open(file_name,'wb')
	file.write(file_new_line)
	file.close()
def rsync_log():
	os.chdir(state_path_ini)
	if os.path.exists('on-going'):
		shutil.rmtree('on-going')
	if os.path.exists('completed'):
		shutil.rmtree('completed')
	os.system("rsync -avc root@192.168.1.10:/home/root/* /var/ftp/pub/ 1>/dev/null 2>&1")
def main_process():
	rsync_log()
	if os.path.exists('status.ini'):
		os.rename('status.ini','status_swap.ini')
	get_config(state_path_ongoing,state_ini)
	get_config(state_path_completed,state_completed_ini)
	convert(state_ini)
	convert(state_completed_ini)
if __name__=='__main__':
	main_process()
