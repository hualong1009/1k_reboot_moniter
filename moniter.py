#coding=utf-8
# Author : Hansen Wang
# Description : Some socket to communicate with remote client.
from socket import *
from zipfile import *
import os,os.path,subprocess
import time,re,service
def stop(a):
	with open(service.blackwords,'r',encoding='utf-8') as blackwords_open:
		lines=blackwords_open.readlines()
	for line in lines:
		print(line,a.split('.')[1])
		if re.match(line.strip(),a.split('.')[1].strip()):
			return(0)
			print(line,a.split('.')[1])
	with open(service.blackwords,'a') as blackwords_open:
		blackwords_open.write(a.split('.')[1]+'\n\r')
	return(0)
def continu(a):
	with open(service.blackwords,'r') as blackwords_open:
		lines=blackwords_open.readlines()
	with open(service.blackwords,'w') as blackwords_open:
		for line in lines:
			if re.match(line.strip(),a.split('.')[1].strip()):
				if len(lines)==1:
					blackwords_open.write("")
				continue
			blackwords_open.write(line)
	return(0)
def zip_file():
	global server_folder
	global zip_file_snd
	if len(server_folder) > 20 :
		os.chdir('/var/ftp/pub/completed')
	else :
		os.chdir('/var/ftp/pub/on-going')
	os.system('zip -qr ../zipfile/'+server_folder+'.zip'+' '+server_folder)
	zip_file_zip=open('../zipfile/'+server_folder+'.zip','rb')
	zip_file_snd=zip_file_zip.readlines()
	zip_file_zip.close()
	os.remove('../zipfile/'+server_folder+'.zip')
def uuid_on(ip):
	on_command="ipmitool -I lanplus -U admin -P admin -H %s raw 00 04 0 01"%ip
	print(on_command)
	status=subprocess.call("timeout 2 "+on_command,shell=True)
	if status == 124:
		return(1)
	else:
		return(0)
def uuid_off(ip):
	off_command="ipmitool -I lanplus -U admin -P admin -H %s raw 00 04 5"%ip
	print(off_command)
	status=subprocess.call("timeout 1 "+off_command,shell=True)
	if status == 124:
		return(1)
	else:
		return(0)
def delete_completed_log(folder,test_status):
	state_ini="/var/ftp/pub/statue.ini"
	if test_status == "Completed" :
		delete_command="ssh root@192.168.1.10 "+'"'+'rm -fr /home/root/completed/'+folder+'"'
	elif test_status == "Stoped" :
		delete_command="ssh root@192.168.1.10 "+'"'+'rm -fr /home/root/on-going/'+folder+'"'
	print(delete_command)
	status=subprocess.call("timeout 5 "+delete_command,shell=True)
	print('...Return_key is '+str(status)+',data type is '+test_status)
	if status == 124:
		return(1)
	elif status == 0 and test_status == "Completed":
		service.rsync_log()
		service.get_config(service.state_path_completed,service.state_completed_ini)
		print('...Return_key is '+str(status)+',data type is '+test_status)
		return(0)
	elif status == 0 and test_status == "Stoped":
		with open(service.state_ini,'r') as delete_log_open:
			delete_log_file=delete_log_open.readlines()
		try:
			delete_count=delete_log_file.index('folder_name='+folder+'\n')
		except ValueError as e:
			print('... '+folder+' is not in list!')
			return(1)
		del(delete_log_file[delete_count-7:delete_count+2])
		print('...Return_key is '+str(status)+',data type is '+test_status)
		with open(service.state_ini,'w') as rewrite_log_open:
			for log_line in delete_log_file:
				print('...'+log_line)
				rewrite_log_open.write(log_line)
		return(0)
	else:
		return(1)
def net_socket():
	global server_folder
	global zip_file_snd
	feedback_pass=" successfully !"
	feedback_fail=" failed !"
	HOST=''
	PORT=19876
	BUFFSIZE=1024*1024
	ADDR=(HOST,PORT)
	ServerSock=socket(AF_INET,SOCK_STREAM)
	ServerSock.bind(ADDR)
	ServerSock.listen(PORT)
	while True:
		for moniterfile in os.listdir('/var/ftp/pub'):
			if re.match(r'\S*moniter\S*',moniterfile):
				moniter=re.match('\S*moniter\S*',moniterfile).group()
				print('Latest 1k_moniter file is : ',moniter)
				version=moniter[11:16]
				print('Latest version is : ',version)
				break
		print('...Waiting for connection!')
		try:
			ClientSock,addr=ServerSock.accept()
		except KeyboardInterrupt as e: 
			ServerSock.close()
			print("Exit!",e)
			exit(0)
		print('...Accept connection from ',addr)
		try :
			data_get=ClientSock.recv(BUFFSIZE).decode('utf-8')
		except ConnectionResetError :
			continue 
		array=data_get.split("|")
		if array[0] == "log":
			server_folder=array[1]
			print('...Start to zip log!'+server_folder)
			zip_file()
			print('...zip list len:'+str(len(zip_file_snd)))
			for data_buff in zip_file_snd:
				ClientSock.send(data_buff)
			print('...Zip file transfer finished!')
		elif array[0] == "stop":
			return_key=stop(array[1])
			if return_key==0 :
				ClientSock.send(bytes(feedback_pass,'utf-8'),1024)
				print("..."+array[0]+' '+array[1]+' '+feedback_pass)
			else:
				ClientSock.send(bytes(feedback_fail,'utf-8'),1024)
				print("..."+array[0]+' '+array[1]+' '+feedback_fail)
		elif array[0] == "continue":
			return_key=continu(array[1])
			if return_key==0 :
				ClientSock.send(bytes(feedback_pass,'utf-8'),1024)
				print("..."+array[0]+' '+array[1]+' '+feedback_pass)
			else:
				ClientSock.send(bytes(feedback_fail,'utf-8'),1024)
				print("..."+array[0]+' '+array[1]+' '+feedback_fail)
		elif array[0] == "uuid_on":
			return_key=uuid_on(array[1])
			if return_key==0 :
				ClientSock.send(bytes(feedback_pass,'utf-8'),1024)
				print("..."+array[0]+' '+array[1]+' '+feedback_pass)
			else:
				ClientSock.send(bytes(feedback_fail,'utf-8'),1024)
				print("..."+array[0]+' '+array[1]+''+feedback_fail)
		elif array[0] == "uuid_off":
			return_key=uuid_off(array[1])
			if return_key==0 :
				ClientSock.send(bytes(feedback_pass,'utf-8'),1024)
				print("..."+array[0]+' '+array[2]+' '+array[1]+''+feedback_pass)
			else:
				ClientSock.send(bytes(feedback_fail,'utf-8'),1024)
				print("..."+array[0]+' '+array[2]+' '+array[1]+''+feedback_fail)
		elif array[0] == "delete":
			return_key=delete_completed_log(array[1],array[2])
			if return_key==0 :
				ClientSock.send(bytes(feedback_pass,'utf-8'),1024)
				print("..."+array[0]+' '+array[2]+' '+array[1]+''+feedback_pass)
			else:
				ClientSock.send(bytes(feedback_fail,'utf-8'),1024)
				print("..."+array[0]+' '+array[2]+' '+array[1]+''+feedback_fail)
		elif array[0] == "download":
			if array[1] == '1k_moniter.exe':
				array[1]=moniter
			log_file=open('/var/ftp/pub/'+array[1],'rb')
			file_snd=log_file.readlines()
			log_file.close()
			for data_buff in file_snd:
				ClientSock.send(data_buff,1024*4)
			print('...'+array[1]+' file transfer finished!')
		elif array[0] == "update":
			if array[1]==version :
				ClientSock.send(bytes('same','utf-8'),1024)
				print("..."+"Local version: "+array[1]+' '+"New version: "+version)
			else:
				ClientSock.send(bytes('diff','utf-8'),1024)
				print("..."+"Local version: "+array[1]+' '+"New version: "+version)
		else:
			ClientSock.send(bytes("Unknown commands !",'utf-8'),1024)
			print("...Unkown commands !")
	ServerSock.close()
def main():
	net_socket()
if __name__ == '__main__':
	main()
