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

/*
 * First, we use the #include directive to import the contents of the
 * TextResponse MediaScript library.
 */
#include "sys:/TextResponse.ms"

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
    scriptName: 'cleanFilenames.ms',
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

/*
 * The global object will hold key/value pairs that control the operation
 * of the script as a whole.
 */
global = {};

/*
 * We define the global key/value pairs here.
 * "macOSFlag" is set to true if the operating system the script runs in is
 * Mac OS X.
 *
 * "lowerCaseFlag" controls whether we normalize filenames to lower case;
 * if false, leave filename case alone.
 *
 * "stripBadFlag" controls whether we strip certain nasty characters out and
 * convert periods and spaces to underscores; if false, leave nasty characters
 * and spaces alone.
 *
 * "normalizeExtFlag" controls whether we set certain file extensions to
 * standard forms; if false, leave the extensions alone.
 * Examples:
 * "jpeg" is set to "jpg"
 * "targa" is set to "tga"
 */
global.macOSFlag = (System.getOSName() === 'MacOSX'), // true : false
global.lowerCaseFlag = false,
global.stripBadFlag = true,
global.normalizeExtFlag = true,

/**
 * checkForFile() is a helper function for determining if a proposed "clean"
 * filename already exists. It is set up as a recurvie function instead a loop
 * because we shouldn't have to check more than a couple of times.
 *
 * @param {String} path  The path where the target file will be placed
 * @param {String} name  The proposed name for the target file
 * @param {String} extensions The file extension of the file
 * @param {Number} counter  The index of the number to be used in the filename
 */
function checkForFile(path, name, extension, counter) {

/*
 * We use a single var statment to declare the function-specific variables,
 * separated by commas.
 * "testName" is the tentative new filename for the file.
 */
    var testName = (counter === 0 ? name : name + '_' + counter);

/*
 * We check if a file with that filename exists. If not, return the name.
 * If so, add "_1" (or increment the number after the "_") and return the result
 * of calling checkForFile() recursively.
 */
    log.debug('checkForFile -> checking filename ' + testName);
    if (new File(path + testName + extension).exists() === false) {
        log.debug('===> checkForFile -> filename ' + testName + ' is available!');
        return testName;
    } else {
        return checkForFile(path, name, extension, counter + 1);
    }
}

/**
 * normalizeExtension() is a helper function for converting certain filename
 * extensions to predetermined formats.
 *
 * @param {String} ext  The file extension
 */
function normalizeExtension(ext) {
/*
 * We use a single var statment to declare the function-specific variables,
 * separated by commas.
 * "extensionMap" is set of key/value mappings.
 */
    var extensionMap = {
        'jpeg': 'jpg',
        'tiff': 'tif',
        'targa': 'tga'
    };

/*
 * If the extension we are checking is a key in extensionMap then return
 * the assoicated value.
 * Otherwise, return the original extension normalized to lower case.
 */
    if (extensionMap[ext.toLowerCase()]) {
        return extensionMap[ext.toLowerCase()];
    } else {
        return ext.toLowerCase();
    }
}

/**
 * The cleanFilenames() function is the main function for the script file.
 * MediaRich uses the XML snippet above to find the script file and the
 * function to call, so the function must have a unique name.
 */
function cleanFilenames() {
    log.info('FUNCTION: cleanFilenames entered');
/*
 * We use a single var statment to declare the function-specific variables,
 * separated by commas.
 * "internalPath" is the path that is pulled from the "input-path" parameter of
 * the MediaRich request
 * "externalPath" is the path that results from converting the internalPath
 * to a form that MediaRich can use.
 */
    var internalPath,
        externalPath,

/*
 * "f" is a File object for the file being manipulated.
 * "filePath" is the path for the original file.
 * "filename" is the path for the original file.
 * "fileExtension" is the file extension for the original file.
 * "targetPath" is the path for the renamed file.
 */
        f,
        filePath,
        filename,
        fileExtension,
        targetPath,

/*
 * We collect the input-path parameter to the MRL request. If there is no
 * input-path paramater then we can't do anything so we throw an exception.
 */
    try {
        internalPath = req.getParameter('input-path');
        if (!internalPath) {
            throw 'Expected a value for "input-path"';
        }

/*
 * Media.InternalToExternal() is a custom MediaRich function.
 * We use it to translate a path from Portfolio Server into a path that
 * MediaRich can use. It's a class method of Media, so we create an anonymous
 * Media object to call the function from.
 */
        externalPath = 'file:' + new Media().InternalToExternal({internal: internalPath});
        log.info('Original file -> ' + externalPath);

/*
 * Once we have the internal path, we create a new File object "f"
 * and the place the path in filePath, the name (without extension) in filename,
 * and the extension in fileExtension.
 */
        f = new File(externalPath);
        filePath = f.getParentPath() + (global.macOSFlag ? '/' : '\\');
        filename = f.getFileNameNoExt();
        fileExtension = f.getFileExtension();

/*
 * If we are set to convert file extensions then we call normalizeExtension()
 * with the current extension and save the result back into fileExtension.
 */
        if (global.normalizeExtFlag) {
            fileExtension = normalizeExtension(fileExtension);
        }

/*
 * If we are set to strip "bad characters" then we call run the filename through
 * two regular expressions. The first takes certain characters out of the
 * filename entirely (\, /, <, >, ?, :, *, and |) and the second replaces
 * space characters with underscores. Then we save the name back into filename.
 */
        if (global.stripBadFlag) {
            filename = filename.replace(/[\/<>?:*|]/g, '').replace(/[.\s]/g, '_');
        }

/*
 * If we are set to normalize filenames to lowercase, we do that here then we
 * save the name back into filename.
 */
        if (global.lowerCaseFlag) {
            filename = filename.toLowerCase();
        }

/*
 * Once we have our new filename, we compare it to the original filename;
 * if nothing has changed then we're done.
 */ 
        if (filename === f.getFileNameNoExt() && fileExtension === f.getFileExtension()) {
            log.debug('new filename is the same as the old. Skipping file.');

/*
 * If the filename has changed then we check to ensure that we don't conflict
 * with an existing file. Then we build our destination file path and
 * rename the file with File.rename().
 */ 
        } else {
            filename = checkForFile(filePath, filename, fileExtension, 0);
            targetPath = filePath + filename + fileExtension;
            f.rename(targetPath);
            log.info('New file -> ' + targetPath);
        }

/*
 * If we throw any exceptions along the way, we write an error message and
 * then rethrow the exception (which should cause the script to abort
 * and report a problem to Portfolio Server).
 */
    } catch (e) {
        log.exception(e);
        log.error('Failed to rename file.');
        throw (e);
    }

/*
 * And we're done!
 */
    log.info('FUNCTION: cleanFilenames exited');
}
