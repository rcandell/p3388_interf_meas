function metadata = importMeta(workbookFile, sheetName, dataLines)
%IMPORTFILE Import data from a spreadsheet
%  METADATA = IMPORTFILE(FILE) reads data from the first worksheet in
%  the Microsoft Excel spreadsheet file named FILE.  Returns the data as
%  a table.
%
%  METADATA = IMPORTFILE(FILE, SHEET) reads from the specified worksheet.
%
%  METADATA = IMPORTFILE(FILE, SHEET, DATALINES) reads from the
%  specified worksheet for the specified row interval(s). Specify
%  DATALINES as a positive scalar integer or a N-by-2 array of positive
%  scalar integers for dis-contiguous row intervals.
%
%  Example:
%  metadata = importfile("D:\meas\Interference-ScottMcNeil\metadata.xlsx", "Sheet1", [3, Inf]);
%
%  See also READTABLE.
%
% Auto-generated by MATLAB on 22-Jan-2025 09:54:58

%% Input handling

% If no sheet is specified, read first sheet
if nargin == 1 || isempty(sheetName)
    sheetName = 1;
end

% If row start and end points are not specified, define defaults
if nargin <= 2
    dataLines = [3, Inf];
end

%% Set up the Import Options and import the data
opts = spreadsheetImportOptions("NumVariables", 5);

% Specify sheet and range
opts.Sheet = sheetName;
opts.DataRange = dataLines(1, :);

% Specify column names and types
opts.VariableNames = ["Name", "MeasFileDir", "MeasFileName", "Distance", "NominalAntennaGain"];
opts.VariableTypes = ["string", "string", "string", "double", "double"];

% Specify variable properties
opts = setvaropts(opts, ["Name", "MeasFileDir", "MeasFileName"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Name", "MeasFileDir", "MeasFileName"], "EmptyFieldRule", "auto");

% Import the data
metadata = readtable(workbookFile, opts, "UseExcel", false);

for idx = 2:size(dataLines, 1)
    opts.DataRange = dataLines(idx, :);
    tb = readtable(workbookFile, opts, "UseExcel", false);
    metadata = [metadata; tb]; %#ok<AGROW>
end

end