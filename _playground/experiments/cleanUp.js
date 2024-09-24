const fs = require("fs");
const path = require("path");

const deleteFolderContents = (folder) => {
  const files = fs.readdirSync(folder); // Read contents of the folder
  for (const file of files) {
    const filePath = path.join(folder, file); // Get the full path of the file/folder
    const stat = fs.lstatSync(filePath); // Get file or folder information

    if (stat.isDirectory()) {
      deleteFolderContents(filePath); // Recursively delete subfolder contents
    } else {
      fs.rmSync(filePath); // Delete file
    }
  }
};

const main = (folders) => {
  for (const folder of folders) {
    deleteFolderContents(folder); // Delete contents of each folder
  }
};

main([
  "_playground/experiments/html",
  "_playground/experiments/images",
  "_playground/experiments/json",
]);
