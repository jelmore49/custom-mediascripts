/*jslint sloppy: false, undef: false, vars: true, white: true */
/*global EMailer, File, IPTCMetadata, Media, req, resp, RespType, Zip */

/**
 * ftpUpload.ms
 * @author Jay Elmore
 *
 * This script uses the FSNet plugin for MediaRich to support transferring
 * files using FTP paths. See page 52 of the MediaRich CORE Programming Guide
 * for details.
 *
 * To make the script available to Portfolio Server, place ftpUpload.ms
 * in the Scripts folder:
 * /Applications/Extensis/Portfolio Server/applications/media-engine/Shared/Originals/Scripts/ (Mac OS X)
 * C:\Program Files\Extensis\Portfolio Server\applications\media-engine\Shared\Originals\Scripts\ (Windows 32-bit)
 * C:\Program Files (x86)\Extensis\Portfolio Server\applications\media-engine\Shared\Originals\Scripts\ (Windows 32-bit)
 *
 * Then, add this XML fragment to media-scripts.xml before the </media-scripts>
 * tag at the end and restart Portfolio Server:
 *
 * <media-script input-style="once-for-all-files" file-output="" source="original" stream-source="false">
 *     <name>Upload Files to FTP Server</name>
 *     <file>ftpUpload.ms</file>
 *     <function>ftpUpload</function>
 *     <metadata>true</metadata>
 *     <language>en</language>
 * </media-script>
 *
 * media-scripts.xml is found in:
 * /Applications/Extensis/Portfolio Server/data/ (Mac OS X)
 * C:\Program Files\Extensis\Portfolio Server\data\ (Windows 32-bit)
 * C:\Program Files (x86)\Extensis\Portfolio Server\data\ (Windows 32-bit)
 *
 * I use the JavaScript object notation instead of the MediaScript
 * "@" notation for named parameters so that my editor doesn't complain as much.
 * See page 49 of the MediaRich CORE Programming Guide for details.
 */

/*
 * First, we use the #link directive to load the EMailer object, so that we have
 * the ability to send emails if configured to do so.
 */
#link <EMailer>

/*
 * We use a single var statment to declare all of our global variables,
 * separated by commas. It's a good JavaScript practice to define all of
 * your variables in one place at each level of scoping, because otherwise
 * it's easy to accidentally define (and set) a variable elsewhere in the code,
 * especially for people who are unfamiliar with JavaScript scoping.
 *
 * The log object defines some basic logging functionality for troubleshooting
 * purposes.
 * You can set the value of log.debugLevel to prevent the script from generating
 * too many messages; by default, it is set to 1.
 * 0 is exceptions only
 * 1 is for error reporting
 * 2 is basic informational messages
 * 3 is more verbose messages for debugging purposes.
 */
var log = {
        debugLevel: 1,
        scriptName: 'ftpUpload.ms',
        debug: function (s) {
            if (this.debugLevel >= 3) {
                print(this.scriptName + ' -- DEBUG: ' + s + '\n');
            }
        },
        info: function (s) {
            if (this.debugLevel >= 2) {
                print(this.scriptName + ' ++ INFO: ' + s + '\n');
            }
        },
        error: function (s) {
            if (this.debugLevel >= 1) {
                print(this.scriptName + ' ## ERROR: ' + s + '\n');
            }
        },
        exception: function (e) {
            if (e instanceof Error) {
                if (e.message && e.message.length > 0) {
                print(this.scriptName + ' !! EXCEPTION: Name "' + e.name + '". Message: "' + e.message + '"\n');
                } else {
                print(this.scriptName + ' !! EXCEPTION: ' + e.name + '.\n');
                }
            } else if (typeof e === 'string' && e.length > 0) {
                print(this.scriptName + ' !! EXCEPTION: ' + e + '\n');
            } else {
                print(this.scriptName + ' !! EXCEPTION: Undefined error.\n');
            }
        }
    },

    // kNameHeader = 'Portfolio-Output-Filename',
/*
 * The ftp and smtp objects will be sets of key/value pairs
 * that hold information specific to your environment. We will define
 * these pairs below.
 * The global object will hold key/value pairs that control the operation
 * of the script as a whole.
 */
    global = {}, ftp = {}, smtp = {};
/*
 * We define the global key/value pairs here.
 * "sendSummaryEmail" controls whether the script sends a summary email
 * after the FTP uploads are complete.
 *
 * "includefileStats" controls whether additional information is appended to the
 * end of the message body.
 */
global.sendSummaryEmail = false;
global.includefileStats = true;

/*
 * The ftp object contains information that pertains to the FTP server
 * that the script will upload the files to. You will want to customize
 * these values to fit your environment.
 *
 * "username" is the name of the login account to be used to authenticate;
 * "password" is the password of the user account, in cleartext (so don't
 * use a sensitive user account for this!)
 *
 * "serverName" is the FQDN or IP address of the FTP server;
 * "folderPath" is the folder path to place the files in (including the trailing
 * slash) starting at the root of the FTP site. If the path you want to use is
 * "ftp://ftp.example.org/incoming/" then set serverName to "ftp.example.org"
 * and folderPath to "incoming/".
 *
 * "port" is the port number to use when connecting; port 21 is standard.
 *
 * "overwriteExisting" controls whether the script replaces an existing
 * file with the same name on the FTP server with the file you are trying
 * to upload. If overwriteExisting is false then the script will not
 * replace the existing file.
 *
 * "archiveAndUpload" controls whether the script archives the selected files
 * in a ZIP archive before uploading. If archiveAndUpload is false then
 * the script will transfer the files individually.
 * "zipFilename" is the name of ZIP archive to be uploaded, if used.
 */
ftp.serverName = 'ftp.example.org';
ftp.username = 'user';
ftp.password = 'password';
ftp.folderPath = 'incoming/';
ftp.port = '21';
ftp.overwriteExisting = true;
ftp.archiveAndUpload = true;
ftp.zipFilename = 'ftpUpload.zip';

/*
 * The smtp object contains information that pertains to the SMTP server
 * that the script will use to send a summary email, if configured to do so.
 * You will want to customize these values to fit your environment.
 *
 * "username" is the email address to be used to authenticate;
 * "password" is the password of the email address, in cleartext. This is
 * fundmentally insecure so don't use a sensitive address for this!
 *
 * "serverName" is the FQDN or IP address of the SMTP server.
 * "port" is the Port number to use when connecting; 25 is the default.
 *
 * "from" is the email address that the email will be addressed from.
 * "to" and "cc" are arrays of strings of email addresses.
 * There must be at least one valid email address in the "to" array, or
 * that the email will be addressed to. If you do not want anyone to be CCed
 * on the email, leave that array empty.
 *
 * "subject" is the subject line of the email.
 * "bodyHeader" is a string to be prepended to the list of file names.
 * that are uploaded.
 * "bodyFooter" is a string to be appended to the list of file names.
 */
smtp.username = '';
smtp.password = '';
smtp.serverName = '127.0.0.1';
smtp.port = '25';
smtp.from = 'jdoe@example.org';
smtp.to = ['jsmith@example.org'];
smtp.cc = [];
smtp.subject = 'FTP Upload Summary';
smtp.bodyHeader = 'The following files have been uploaded to the FTP Server: \n';
smtp.bodyFooter = '\nItems processed via Portfolio Server at Example.org.\n';

/**
 * The ftpUpload() function is the main function for the script file.
 * MediaRich uses the XML snippet above to find the script file and the
 * function to call, so the function must have a unique name.
 */
function ftpUpload() {
    log.info('FUNCTION: ftpUpload entered');

/*
 * We use a single var statment to declare the function-specific variables,
 * separated by commas.
 *
 * "bodyText" will contain the final text for the email body as a string.
 * "emailBody" is used to build the text as the function executes.
 */
    var bodyText,
        emailBody = '',

/*
 * "fileStats" is an array of strings to be used for the file stats portion
 * of the email (if used). We're using an array because Array.join() is faster
 * than string concatenation operations, and we can use line breaks as
 * delimiters in the resulting string.
 */
        fileStats = ['=====Uploaded File Statistics====='],

/*
 * "internalPath" is the path that is pulled from the "input-path-" parameter of
 * the MediaRich request 
 * "externalPath" is the path that results from converting the internalPath
 * to a form that MediaRich can use.
 * "targetPath" is the FTP path we will use to upload the file.
 * "pathForLog" is similar to targetPath but we obfuscate the username
 * and password to be used in the FTP path.
 */
        internalPath,
        externalPath,
        targetPath,
        pathForLog,

/*
 * "file" is a File object for the current file we are processing
 * in the while loop.
 * "filename" is the filename of the current file; we do this to
 * reduce the number of calls to File.getFileName().
 * "fileSize" is the size of the current file. 
 */
        file,
        filename,
        fileSize,
/*
 * "myZip" is the Zip object for uploading. However, if we are not
 * uploading a ZIP archive, we leave it set to null.
 */
        myZip = ((ftp.archiveAndUpload) ? new Zip() : null),

/*
 * "msg" is the EMailer object to be used to send a summary email.
 * However, if we are not sending an email, we leave it set to null.
 */
        msg = ((global.sendSummaryEmail) ? new EMailer() : null),
/*
 * "i" and "pathidx" are counters.
 */
        i,
        pathidx = 1;

/**
 * buildFTPPath() is an inner function to build an FTP path string
 * for MediaRich to use.
 *
 * We're not passing the object we defined before because we also use
 * this to generate FTP path strings for the summary email, and we want to
 * obfuscate the username and password.
 *
 * @param {String} serverName  The FQDN or IP address of the FTP server
 * @param {String} port  The port that the FTP server is listening to
 * @param {String} username  The user account to authenticate with
 * @param {String} password  The password to authenticate with, in cleartext
 * @param {String} folderPath  The path from the FTP root to use
 * @param {String} filename  The name of the file
 */
    function buildFTPPath(serverName, port, username, password, folderPath, filename) {
        return 'ftp://' +
            ((username !== '' && password !== '') ? (username + ':' + password + '@') : '') +
            serverName +
            ((port !== '' && port !== '21') ? (':' + port) : '') +
            ((folderPath !== '') ? ('/' + folderPath) : '/') +
            filename;
    }

/*
 * We process the input-path parameters to the MRL request in order to build
 * an array of file paths. We do this in a while loop because
 * we don't know how many paths are being passed.
 */
    while (true) {
        try {
            internalPath = req.getParameter('input-path-' + pathidx);
/*
 * The first time we get an invalid parameter, we break out of the loop.
 */
            if (!internalPath) {
                break;
            }

/*
 * Media.InternalToExternal() is a custom MediaRich function.
 * We use it to translates a path from Portfolio Server into a path that
 * MediaRich can use. It's a class method of Media, so we create an anonymous
 * Media object to call the function from. After that, we push the file path
 * into fileStats.
 */
            log.debug('input-path-' + pathidx + ': ' + internalPath);
            externalPath = 'file:' + new Media().InternalToExternal({internal: internalPath});
            log.debug('Source file path: ' + externalPath);
            fileStats.push('Source file path: ' + externalPath);

/*
 * We create a File object using the externalPath, and put the filename in filename
 * and the file size in fileSize for reporting purposes. File.getSize() returns
 * the file size in bytes, so we convert to kilobytes, then multiply by 10,000,
 * round down, then divide by 10,000 to get a pretty number for the report.
 * We then push the file size into fileStats.
 */
            // Get the file size
            file = new File(externalPath);
            filename = file.getFileName();
            fileSize = Math.round((file.getSize() / 1024) * 10000) / 100000;
            log.debug('Source file size : ' + fileSize.toFixed(1) + ' MB');
            fileStats.push('Source file size : ' + fileSize.toFixed(1) + ' MB');
/*
 * If we are uploading the files in a ZIP archive, then add the file to myZip.
 */
            if (ftp.archiveAndUpload) {
                log.debug('Adding ' + filename + ' to zip archive');
                myZip.addFile(externalPath, filename);
/*
 * Otherwise, then we generate the FTP path for the file (and an obfuscated path
 * for the summary email).
 */
            } else {
                targetPath = buildFTPPath(ftp.serverName, ftp.port, ftp.username, ftp.password, ftp.folderPath, filename);
                pathForLog = buildFTPPath(ftp.serverName, ftp.port, '*****', '*****', ftp.folderPath, filename);
/*
 * We push the FTP path into fileStats
 */
                fileStats.push('FTP Upload URL: ' + pathForLog);
                log.debug('FTP Upload URL: ' + pathForLog);

/*
 * If we aren't going to overwrite existing files and the file exists, then we
 * push a message indicating this into fileStats and keep going.
 */
                if (ftp.overwriteExisting && new File(targetPath).exists()) {
                    fileStats.push('File ' + filename + ' exists and overwrite of existing files not allowed; file not uploaded');
                    log.info('File ' + filename + ' exists and overwrite of existing files not allowed; file not uploaded');

/*
 * Otherwise, we use File.copy() to upload the file using the FTP path
 * and push a message into fileStats.
 * If we are sending a summary email, then we add the path and file size
 * to emailBody.
 */
                } else {
                    file.copy(targetPath);
                    fileStats.push('File ' + filename + ' uploaded');
                    log.debug('File ' + filename + ' uploaded');
                    if (global.sendSummaryEmail) {
                        emailBody += 'Upload location: ' + pathForLog;
                        emailBody += '(Size: ' + fileSize.toFixed(1) + ' MB)\n';
                    }
                }
            }

/*
 * If we throw any exceptions along the way, we write an error message and
 * then rethrow the exception (which should cause the script to abort
 * and report a problem to Portfolio Server).
 */
        } catch (e1) {
            log.exception(e1);
            log.error('Failed to transfer file.');
            throw (e1);
        }

/*
 * Then we increment the counter we are using for the input-path parameter
 * index, and close the while loop.
 */
        pathidx += 1;
    }

/*
 * If we are uploading the files in a ZIP archive and the archive exists,
 * we generate an FTP path for the ZIP archive and push it into fileStats.
 */
    try {
        if (ftp.archiveAndUpload && myZip !== null) {
            log.debug('Uploading zip archive\n');
            targetPath = buildFTPPath(ftp.serverName, ftp.port, ftp.username, ftp.password, ftp.folderPath, ftp.zipFilename);
            pathForLog = buildFTPPath(ftp.serverName, ftp.port, '*****', '*****', ftp.folderPath, ftp.zipFilename);
            fileStats.push('FTP Upload URL: ' + pathForLog);
            log.debug('FTP Upload URL: ' + pathForLog);

/*
 * If we aren't going to overwrite existing files and the ZIP archive exists,
 * then we push a message indicating this into fileStats and keep going.
 */
            if (ftp.overwriteExisting && new File(targetPath).exists()) {
                fileStats.push('File ' + ftp.zipFilename + ' exists and overwrite of existing files not allowed; file not uploaded');
                log.info('File ' + ftp.zipFilename + ' exists and overwrite of existing files not allowed; file not uploaded');
/*
 * Otherwise, we use Zip.save() to upload the ZIP archive using the FTP path
 * and push a message into fileStats.
 * If we are sending a summary email, then we add the path and archive size
 * to emailBody.
 */
            } else {
                myZip.save(targetPath);
                fileStats.push('File ' + ftp.zipFilename + ' uploaded');
                log.debug('File ' + ftp.zipFilename + ' uploaded');
                if (global.sendSummaryEmail) {
                    emailBody += 'Upload location: ' + pathForLog;
                    emailBody += '(Size: ' + fileSize.toFixed(1) + ' MB)\n';
                }
            }
        }
/*
 * If we throw any exceptions along the way, we write an error message and
 * then rethrow the exception (which should cause the script to abort
 * and report a problem to Portfolio Server).
 */
    } catch (e2) {
        log.exception(e2);
        log.error('Failed to transfer file.');
        throw (e2);
    }

/*
 * If we are going to send a summary email, then we start by setting the
 * SMTP server name (and port, if necessary) in msg.
 */
    if (global.sendSummaryEmail) {
        try {
            if (smtp.port !== '' && smtp.port !== '25') {
                msg.setServer(smtp.serverName + ':' + smtp.port);
                log.debug('SMTP server: ' + smtp.serverName + ':' + smtp.port + '\n');
            } else {
                msg.setServer(smtp.serverName);
                log.debug('SMTP server: ' + smtp.serverName + '\n');
            }

/*
 * Then we set the username and password, if not left blank.
 */
            if (smtp.username !== '') {
                msg.setUsername(smtp.username);
            }
            if (smtp.password !== '') {
                msg.setPassword(smtp.password);
            }

/*
 * Then we set the subject and the From address. We then iterate the
 * arrays of email address to be used in the To and CC lines and add them.
 */
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

/*
 * We build the message body by starting with the header, adding the body
 * text that we have been generating, then adding the footer.
 * If we are including file stats, then that array of strings is merged
 * into a single string and added before the footer.
 */
            bodyText = smtp.bodyHeader;
            bodyText += '\n\n' + emailBody;
            if (global.includefileStats) {
                bodyText += '\n\n' + fileStats.join('\n');
            }
            bodyText += '\n\n' + smtp.bodyFooter;
            log.debug('Body of email:\n' + bodyText);

/*
 * We set the message body to our generated text, then attempt to send
 * the email using EMailer.send().
 */
            msg.setMessage(bodyText);
            msg.send();
/*
 * If we throw an exception, we write an error message and then rethrow
 * the exception (which should cause the script to abort and report
 * a problem to Portfolio Server).
 */
        } catch (e3) {
            log.exception(e3);
            log.error('Failed to send email.');
            throw (e3);
        }
    }

/*
 * And we're done!
 */
    log.info('FUNCTION: ftpUpload exited');
}
