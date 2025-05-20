// Collapse all Z-stacks in a folder to max projections

inputDir  = getDirectory("Choose input folder");
outputDir = getDirectory("Choose output folder");
fileList  = getFileList(inputDir);

for (i = 0; i < fileList.length; i++) {
    name = fileList[i];
    if (endsWith(name, ".tif") || endsWith(name, ".tiff")) {
        open(inputDir + name);
        title = getTitle();
        
        run("Z Project...", "projection=[Max Intensity]");
        
        projTitle = "MAX_" + title;
        selectWindow(projTitle);
        saveAs("Tiff", outputDir + "proj_" + title);
        close();
        selectWindow(title);
        close();
    }
}
