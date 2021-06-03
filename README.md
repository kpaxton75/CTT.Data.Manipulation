# CTT.Data.Manipulation

R scripts to get raw beep data and node health data - similar to CTT load_data() function BUT see below for differences
1. Import_beep.data.Github - contains Code to import raw detections (or beeps) from multiple Sensor Stations for a specified time period
                           - see the beginning of the script for detailed information about files needed to run the code and output generated from the code

2. Import_node.health.data.Github - contains code to import node health files from multiple Sensor Stations for a specified time period and create diagnostics
                                  - see the beginning of the script for detailed information about files needed to run the code and output generated from the code

3. Functions_CTT.Network.R - contains functions to run code in Import_node.health.data.Github and Import_beep.data.Github


IMPORTANT Differences from CTT load_data() function
1. Separate R scripts to import beep data and node health data

2. R scripts only import .csv files associated with the date range specified by the user 
    **** each user MUST change the code in Functions_CTT.Network.R line 27 (for raw beep data) and line 139 (for node health data) to match their data format ****
  
        For example with Raw Beep data files
           - When you download data from CTT using API - all csv files of raw beep data will be in a folder for your project and within that folder there will be  
             folders for each Base Station and within each Base Station folder there will be a folder named 'raw' that has raw beep data
              Ex. "/Users/kpaxton/DataFiles_CTT/Guam Sali/8EEEF7F20F8E/raw/CTT-8EEEF7F20F8E-raw-data.2020-08-26_111951.csv"
                  --  'Guam Sali' is the folder name of the Project
                  -- '8EEEF7F20F8E' is the folder name of the Sensor Station - all base stations are 12 characters
                  -- 'raw' is the folder name with raw beep data 
                  -- 'CTT-8EEEF7F20F8E-raw-data.2020-08-26_111951.csv' is an example file name within the raw folder
                  --  Everything prior to Project Name is the path on the computer where the files are found
            - Currently in Functions_CTT.Network.R line 27 indicates that the date of the raw data file starts at the 44th character and ends at the 53rd character 
               when counting from the Sensor Station name in the path
               
3. R scripts will add a column named 'SensorId' to indicate the Sensor Station (or Base Station) where the data was gathered
    --- For raw beep data import, duplicated data from multiple base stations will be removed
    
4. R scripts add a column named 'Time.local' that indicates the timestamp for the local timezone specified by the user 
    **** For downstream data processing using CTT scripts having a second column with POSIXct format may cause problems and scripts will have to be slightly modified 
         in order to keep this column ****
       
5. R scripts save outputs of beep and node health data as RDS files (R data files) because this file type saves the format of each column when files are uploaded to R (unlike .csv files)
    **** Users will need to change line 111 (beep data) line 211 (node health data) in Functions_CTT.Network.R from 'saveRDS' to  'write.csv' and '.rds' to '.csv' if they prefer .csv files ****
       
6. Import_beep.data.Github script filters data to only include the RadioId(s) specified by the user

7. Import_beep.data.Github script filters rows with NAs produced in the 'NodeId' column when data is collected from a Sensor Station
     **** Users that are using beep data collected from the Sensor Station will need to comment out line 93 in Functions_CTT.Network.R ****
     
8. Import_node.health.data.Github script also has separate code for creating diagnostic plots and information on node health
