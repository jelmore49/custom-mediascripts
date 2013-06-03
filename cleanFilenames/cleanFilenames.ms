/*jslint sloppy: true, undef: false, vars: true, white: true */
/*global File, Media, req, System */

/**
 * cleanFilenames.ms
 * @author Jay Elmore
 *
 * To make the script available to Portfolio Server, place cleanFilenames.ms
 * in the Scripts folder:
 * /Applications/Extensis/Portfolio Server/applications/media-engine/Shared/Originals/Scripts/ (Mac OS X)
 * C:\Program Files\Extensis\Portfolio Server\applications\media-engine\Shared\Originals\Scripts\ (Windows 32-bit)
 * C:\Program Files (x86)\Extensis\Portfolio Server\applications\media-engine\Shared\Originals\Scripts\ (Windows 32-bit)
 *
 * Then, add this XML fragment to media-scripts.xml before the </media-scripts>
 * tag at the end and restart Portfolio Server:
 *
 * <media-script input-style="once-per-file" file-output="">
 *     <name>Clean Filenames</name>
 *     <file>cleanFilenames.ms</file>
 *     <function>cleanFilenames</function>
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

#include "sys:/TextResponse.ms"

var kNameHeader = 'Portfolio-Output-Filename',
	macOSFlag = (System.getOSName() === 'MacOSX'), // true : false

	// Can we receive these as parameters? If so, set them here
	// If true, we want to normalize filenames to lower case; if false, leave filename case alone
	lowerCaseFlag = false,

	// If true, we want to strip nasty characters out and convert periods and spaces to underscores; if false, leave nasty characters and spaces alone
	stripBadFlag = true,

	// If true, we want to normalize file extensions (jpeg -> jpg, targa -> tga, etc.); if false, leave file extension alone
	normExtFlag = true,

	log = {
		debugLevel: 3, // "0" is exceptions only, "1" is error, "2" is info, and "3" is debug. Default should be 1
		scriptName: 'cleanFilenames.ms',
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
	};

function checkForFile(path, name, extension, counter) {
	var testName = (counter === 0 ? name : name + '_' + counter);
	log.debug('checkForFile -> checking filename ' + testName);

	/*
	 * We're checking if a file with that filename exists.
	 * If so, add "_1" (or increment the number after the "_") and check again.
	 */
	if (new File(path + testName + extension).exists() === false) {
		log.debug('===> checkForFile -> filename ' + testName + ' is available!');
		return testName;
	} else {
		return checkForFile(path, name, extension, counter + 1);
	}
}

function normalizeExtension(ext) {
	var extensionMap = {
		'jpeg': 'jpg',
		'tiff': 'tif',
		'targa': 'tga'
	};
	if (extensionMap[ext]) {
		return extensionMap[ext].toLowerCase();
	} else {
		return ext.toLowerCase();
	}
}

function cleanFilenames() {
	log.info('FUNCTION: cleanFilenames entered');
	var f, m, internalPath, externalPath, fileExtension, fileName, filePath, targetPath;

	try {
		internalPath = req.getParameter('input-path');
		if (!internalPath) {
			throw 'Expected a value for "input-path"';
		}

		m = new Media();
		externalPath = 'file:' + m.InternalToExternal({internal: internalPath});

		log.info('Original file -> ' + externalPath);

		f = new File(externalPath);
		filePath = f.getParentPath() + (macOSFlag ? '/' : '\\');
		fileName = f.getFileNameNoExt();
		fileExtension = f.getFileExtension();

		if (normExtFlag) {
			fileExtension = normalizeExtension(fileExtension);
		}
		if (stripBadFlag) {
			fileName = fileName.replace(/[\/<>?:*|]/g, '').replace(/[.\s]/g, '_');
		}
		if (lowerCaseFlag) {
			fileName = fileName.toLowerCase();
		}

		// If our filename didn't actually change, then don't do anything
		if (fileName === f.getFileNameNoExt() && fileExtension === f.getFileExtension()) {
			log.debug('new filename is the same as the old. Skipping file.');
		} else {
			fileName = checkForFile(filePath, fileName, fileExtension, 0);
			targetPath = filePath + fileName + fileExtension;
			f.rename(targetPath);
			log.info('New file -> ' + targetPath);
		}
	} catch (e) {
		log.exception(e);
		log.error('Failed to rename file.');
		throw (e);
	}

	log.info('FUNCTION: cleanFilenames exited');
}
