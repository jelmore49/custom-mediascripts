/*jslint sloppy: false, undef: false, vars: true, white: true */
/*global EMailer, File, IPTCMetadata, Media, req, resp, RespType, Zip */

/*
 * Configure FTP file system variables here:
 * C:\Program Files\Extensis\Portfolio Server\applications\media-engine\Properties\local.properties
 * See the MediaRich Core Programming Guide for the details on the FSNet plugin
 * NOTE: I use the JavaScript object notation instead of the MediaScript @ notation, so that my JS editor doesn't complain
 */
#link <EMailer>
#include "sys:/TextResponse.ms"

var kNameHeader = 'Portfolio-Output-Filename',
	log = {
		debugLevel: 3, // "0" is exceptions only, "1" is error, "2" is info, and "3" is debug. Default should be 1
		scriptName: 'ftpUpload.ms',
		debug: function (s) {
			if (this.debugLevel >= 3) {
				print(this.scriptName + '-- DEBUG: ' + s + '\n');
			}
		},
		info: function (s) {
			if (this.debugLevel >= 2) {
				print(this.scriptName + '++ INFO: ' + s + '\n');
			}
		},
		error: function (s) {
			if (this.debugLevel >= 1) {
				print(this.scriptName + '## ERROR: ' + s + '\n');
			}
		},
		exception: function (e) {
			if (e instanceof Error) {
				if (e.message && e.message.length > 0) {
				print(this.scriptName + '!! EXCEPTION: Name "' + e.name + '". Message: "' + e.message + '"\n');
				} else {
				print(this.scriptName + '!! EXCEPTION: ' + e.name + '.\n');
				}
			} else if (typeof e === 'string' && e.length > 0) {
				print(this.scriptName + '!! EXCEPTION: ' + e + '\n');
			} else {
				print(this.scriptName + '!! EXCEPTION: Undefined error.\n');
			}
		}
	},
	ftp = {}, smtp = {},
	sendSummaryEmail = false; // send summary email after FTP uploads are complete

// FTP server info
ftp.username = 'user'; // Login name to authenticate to FTP Server
ftp.password = 'password'; // Login password to authenticate to FTP Server
ftp.servername = 'ftp.example.org'; // Server DNS name or IP
ftp.folderPath = 'incoming/'; // If not at root level of FTP site, enter folder path here. Ex: ftp://ftp.example.org/incoming/
ftp.port = '21'; // FTP Port: 21 by default
ftp.overwriteExisting = true; // If the file exists on the FTP Server then overwrite it, otherwise skip.
ftp.archiveAndUpload = true; // Zip all the files before transferring
ftp.zipFilename = 'ftpUpload.zip';

// SMTP server info
smtp.username = 'jdoe@example.org'; // Login name to authenticate to SMTP Server
smtp.password = 'password'; // Login password to authenticate to SMTP Server
smtp.servername = '127.0.0.1'; // Server DNS name or IP
smtp.port = '25'; // SMTP Port: 25 by default
smtp.from = 'jdoe@example.org'; // String - email address
smtp.to = ['jsmith@example.org']; // Array of strings - multiple email addresses OK
smtp.cc = ['fsmith@companyxyz.com', 'fdoe@example.org']; // Array of strings - multiple email addresses OK
smtp.subject = 'FTP Upload Summary';
smtp.bodyHeader = 'The following files have been uploaded to the FTP Server: \n';
smtp.bodyFooter = '\nItems processed via Portfolio Server at Example.org.\nTo report abuse; contact the help desk: help@example.org\n';
smtp.includefileStats = true; // Include additional statistics at the end of the email.

function ftpUpload() {
	"use strict";
	log.info('FUNCTION: ftpUpload entered');

	var i, bodyText,
		emailBody = '',
		file,
		filename,
		fileStats = ['=====Uploaded File Statistics====='],
		fSize,
		generatedPath,
		inputPaths = [],
		localFilePath,
		msg,
		myZip = ((ftp.archiveAndUpload) ? new Zip() : null),
		path,
		pathForLog,
		pathidx = 1;

	function buildFTPPath(servername, port, username, password, folderPath) {
		return 'ftp://' +
		((username !== '' && password !== '') ? (username + ':' + password + '@') : '') +
		servername +
		((port !== '' && port !== '21') ? (':' + port) : '') +
		((folderPath !== '') ? ('/' + folderPath) : '/');
	}

	// Build array of file paths
	while (true) {
		try {
			path = req.getParameter('input-path-' + pathidx);
			if (!path) {
				break;
			}
			log.debug('input-path-' + pathidx + ': ' + path);

			localFilePath = 'file:' + new Media().InternalToExternal({internal: path});
			log.debug('Source file path: ' + localFilePath);
			fileStats.push('Source file path: ' + localFilePath);

			// Get the file size
			file = new File(localFilePath);
			fSize = Math.round(file.getSize() / 1024 * 100000) / 100000;
			log.debug('Source file size : ' + fSize.toFixed(1) + ' MB');
			fileStats.push('Source file size : ' + fSize.toFixed(1) + ' MB');

			filename = file.getFileName();
			if (ftp.archiveAndUpload) {

				// Add file to zip archive we're creating
				log.debug('Adding ' + filename + ' to zip archive');
				myZip.addFile(localFilePath, filename);
			} else {
				generatedPath = buildFTPPath(ftp.servername, ftp.port, ftp.username, ftp.password, ftp.folderPath) + filename;
				pathForLog = buildFTPPath(ftp.servername, ftp.port, ftp.username, '*****', ftp.folderPath) + filename;

				fileStats.push('FTP Upload URL: ' + pathForLog);
				log.debug('FTP Upload URL: ' + pathForLog);

				if (ftp.overwriteExisting && new File(generatedPath).exists()) {
					fileStats.push('File ' + filename + ' exists and overwrite of existing files not allowed; file not uploaded');
					log.info('File ' + filename + ' exists and overwrite of existing files not allowed; file not uploaded');
				} else {
					file.copy(generatedPath);
					fileStats.push('File ' + filename + ' uploaded');
					log.debug('File ' + filename + ' uploaded');
					if (sendSummaryEmail) {
						emailBody += 'Upload location: ' + pathForLog;
						emailBody += '(Size: ' + fSize.toFixed(1) + ' MB)\n';
					}
				}
			}
		} catch (e1) {
			log.exception(e1);
			log.error('Failed to transfer file.');
			throw (e1);
		}
		pathidx += 1;
	}

	// If we're uploading a zipfile instead, do that here.
	try {
		log.debug('Uploading zip archive\n');
		if (ftp.archiveAndUpload && myZip !== null) {
			generatedPath = buildFTPPath(ftp.servername, ftp.port, ftp.username, ftp.password, ftp.folderPath) + ftp.zipFilename;
			pathForLog = buildFTPPath(ftp.servername, ftp.port, ftp.username, '*****', ftp.folderPath) + ftp.zipFilename;

			fileStats.push('FTP Upload URL: ' + pathForLog);
			log.debug('FTP Upload URL: ' + pathForLog);

			if (ftp.overwriteExisting && new File(generatedPath).exists()) {
				fileStats.push('File ' + filename + ' exists and overwrite of existing files not allowed; file not uploaded');
				log.info('File ' + filename + ' exists and overwrite of existing files not allowed; file not uploaded');
			} else {
				myZip.save(generatedPath);
				fileStats.push('File ' + ftp.zipFilename + ' uploaded');
				log.debug('File ' + ftp.zipFilename + ' uploaded');
				if (sendSummaryEmail) {
					emailBody += 'Upload location: ' + pathForLog;
					emailBody += '(Size: ' + fSize.toFixed(1) + ' MB)\n';
				}
			}
		}
	} catch (e2) {
		log.exception(e2);
		log.error('Failed to transfer file.');
		throw (e2);
	}

	if (sendSummaryEmail) {
		try {
			msg = new EMailer();
			if (smtp.port !== '' && smtp.port !== '25') {
				msg.setServer(smtp.servername + ':' + smtp.port);
				log.debug('SMTP server: ' + smtp.servername + ':' + smtp.port + '\n');
			} else {
				msg.setServer(smtp.servername);
				log.debug('SMTP server: ' + smtp.servername + '\n');
			}

			if (smtp.username !== '') {
				msg.setUsername(smtp.username);
			}
			if (smtp.password !== '') {
				msg.setPassword(smtp.password);
			}

			msg.setSubject(smtp.subject);
			msg.setFromAddress(smtp.from);

			for (i = 0; i < smtp.to.length; i++) {
				msg.addToAddress(smtp.to[i]);
			}
			if (smtp.cc.length > 0) {
				for (i = 0; i < smtp.cc.length; i++) {
					msg.addCcAddress(smtp.cc[i]);
				}
			}

			bodyText = smtp.bodyHeader;
			bodyText += '\n\n' + emailBody;
			if (smtp.includefileStats) {
				bodyText += '\n\n' + fileStats.join('\n');
			}
			bodyText += '\n\n' + smtp.bodyFooter;
			log.debug('Body of email:\n' + bodyText);

			msg.setMessage(bodyText);
			msg.send();
		} catch (e3) {
			log.exception(e3);
			log.error('Failed to send email.');
			throw (e3);
		}
	}

	log.info('FUNCTION: ftpUpload exited');
}
