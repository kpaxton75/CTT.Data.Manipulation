##########################################################################################################################################################
##
##    Kristina L Paxton
##    
##    October 26 2020
##
##    Code to import node health files from multiple Sensor Stations and Create Diagnostics for a specified time period
##
##    Files Needed
##        1. Nodes.csv file with a list of all nodes in your network that is saved in the working directory defined below
##            - Column names needed: NodeId
##            - Other columns can also be in the file for your reference (e.g., longitude and latitude)
##            - Ensure all letters in NodeId are capitalized 
##            - If Node names are being converted to scientific notation in Excel open the file with a text editor (e.g. BBedit) to change names to the correct format and save the file
##
##        2. BaseStations.csv file with a list of base stations in your network and their latitude and longitude that is saved in the working directory defined below
##            -- Column names needed: BaseId, lng, lat
##            -- other columns can also be in the file for your reference
##            -- Ensure all letters in BaseId are capitalized
##
##        3. Functions_CTT.Network.R file that contains function to run the script below - saved in the working directory defined below
##
##        4. Node health data files
##            - When you download data from CTT using API - all csv files of node health data will be in a folder for your project and within that folder there will be folders for each Base Station 
##             - and within each Base Station folder there will be a folder named 'node' that has node health data
##                   Ex. "/Users/kpaxton/DataFiles_CTT/Guam Sali/8EEEF7F20F8E/node_health/CTT-8EEEF7F20F8E-node-health.2020-09-17_032822.csv.gz"
##                         --  'Guam Sali' is the folder name of the Project
##                         -- '8EEEF7F20F8E' is the folder name of the Sensor or Base Station 
##                         -- 'node_health' is the folder name with node health data 
##                         -- 'CTT-8EEEF7F20F8E-node-health.2020-09-17_032822.csv.gz' is an example file name within the node folder
##                         --  Everything prior to Project Name is the path on the computer where the files are found
##            - Verify that the date of the node health data file starts at the 55th character and ends at the 66th character when counting from the Sensor Station name in the path
##              ***** if this is not true for your data then you will need to change the numbers in Functions_CTT.Network.R line 139 to match your data **************
##     
##       
##    Node Health Diagnostics Created
##        1. All Node Health Data - all node health data imported for the period of time specified
##              - Exported as a .rds file to your outpath named - node_data_Start.Date_End.Date.rds
##              - A copy of this data will also be created in your working environment called - health.dat
##
##        2. Node Health Data for Nodes with Latitude and Longitude coordinates outside of the coordinates designated
##              - In your working environment called - bad.locations.dat
##
##        3. Node Locations - average lat and long of Nodes detected by CTT for the period of time indicated
##              - Exported as csv file to your outpath named  - Node.Location.Averages_Start.Date_End.Date.csv
##
##        4. Nodes Missing - Nodes that are in your list of nodes, but are not being picked up by CTT Network (Status = Missing_ML)
##              - Exported as csv file to your outpath named - Missing.Nodes_Start.Date_End.Date.csv
##
##        5. Figures of Node RSSI values - A figure of each Node and the RSSI value of that node for a given Base Station for the specified time period
##              - Exported as a pdf file to your outpath named - NodeBattery_ByDate_Start.Date_End.Date.pdf
##
##        6. Node Battery Levels - A figure of each Node and the Battery Power Level of that node for a given Base Station for the specified time period
##              - Exported as a pdf file to your outpath named - NodeRSSI_ByDate_Start.Date_End.Date.pdf
##
##        7. Map of Nodes and Base Stations - A map of the Nodes and Base Stations with a satelitte background for the specified time period
##              - Exported as a pdf file to your outpath named - Node.Locations_Sat.Base.Map_Start.Date_End.Date.pdf
#########################################################################################################################################################


# packages needed
library(dplyr)
library(tidyr)
library(lubridate)
library(stringr)
library(ggplot2)
library(ggforce)

# For Spatial dataframes to make maps
library(raster)
library(sp)
library(rgdal)
library(ggmap)

### Set by User
  # Working Directory - Provide/path/on/your/computer/where/master/csv/file/of/nodes/is/found/and/where/Functions_CTT.Network.R/is/located
working.directory <- " add here "

  # Directory for Output data - Provide/path/where/you/want/output/data/to/be/stored/
outpath <- " add here - make sure it ends with a /"


# Bring in functions 
setwd(working.directory)
source("Functions_CTT.Network.R")

# Bring in File with Node and Base Station Locations
nodes <- read.csv("Nodes.csv", header = T)
str(nodes) # check that data imported properly
base <- read.csv("BaseStations.csv", header = T)
str(base)  # check that data imported properly




###### Run function to get node health data and a count of the detections removed at different steps  #########
  
  ## Variables to define for function
        ## INFILE = Path where folders for multiple sensor stations are found 
        ## NODE.VERSION = Version of CTT node (needed for some CTT work flows)
        ## TIMEZONE = Time zone where data was collected, use grep("<insert location name here>", OlsonNames(), value=TRUE) to find valid time zone name
        ## START & END = date range of data to process (format: "YYYY-MM-DD"), also removes any stray dates 
        ## LAT.LOWER & LAT.UPPER = Lower and Upper latitude of your study area (all points that do not fall within these values will be exported to bad.locations.dat file)
        ## LONG.LOWER & LONG.UPPER = Lower and Upper longitude of your study area (all points that do not fall within these values will be exported to bad.locations.dat file)
        ## ZOOM = zoom level of the map generated showing node locations for your study area, an integer from 3 (continent) to 21 (building) - may need to try a few values to determine correct number for your study area

  
  ## Output in R environment
      # nodehealth.output - list containing:
                          # node_data (all node data meeting specified time period and contained within the study area), 
                          # Nodes_Bad.Locations (node data with Lat or Long outside of the study area)
                          # node.version (CTT version of nodes)
                          # count.import (number of rows imported)
                          # count.NA (number of rows removed that had NA values - e.g. BaseStations have NA for NodeId)
                          # count.date (number of rows removed that did not fall within specified time period)
                          # count.nodes (number of rows removed where the NodeId did not match the NodeId in the provided lookup table)
  ## Output saved
     # .rds file of the node_data save in the specified outpath


# Variables to define for function below - replace values below with user specified values -
INFILE <- "/Users/kpaxton/DataFiles_CTT/Guam Sali"
NODE.VERSION <- 2
TIMEZONE <- "Pacific/Guam"
START <- "2021-05-01"
END <- "2021-05-30"
ZOOM <- 15

# Function to import node health data -- need to define Lat and Long information below based on the boundaries of your study area-- NO quotes
node.health.output <- import.node.health(INFILE, NODE.VERSION, RADIOID, TIMEZONE, START, END,
                                         LAT.LOWER = 13.550, LAT.UPPER = 13.600, LONG.LOWER = 144.900, LONG.UPPER = 144.950)


# Make a data frame of node health data to use in next steps
health.dat <- node.health.output[[1]]
str(health.dat)

# Make a dataframe of node health data with Latitude and Longitude coordinates outside of the specified values
  # For your reference to potentially identify Nodes not working properly
bad.locations.dat <- node.health.output[[7]]



##### Run functions to make a pdf with plots of Node RSSI (or Battery Voltage) within the specified range of dates with different colors for each Base Station #########
  ## Output saved
      ## Figures will NOT appear in R environment
      ## A pdf with a figure of each node will be saved in the specified outpath - 4 columns and 4 rows of Nodes per page of the pdf
  
# Node RSSI by Time Period
Node.RSSI.Plot(health.dat)

# Battery Voltage by Time Period
Node.Battery.Plot(health.dat)



### Run Function to calculate average lat and long for each node and indicate any Nodes not being picked up by CTT Network

  ## Output in R Enviroment
    ## node.loc.summary - dataframe with the average lat and long for each node based on node health data
  ## Output saved
    ## .csv file of the node.loc.summary
    ## .csv file of Nodes in your list of nodes that were not detected by CTT Network during the specified time period

node.loc.summary <- Node.Avg.Location(health.dat)




#### Run function to make a map of Nodes and Base Stations with a Satellite Background based on current node health data ####

  ## Output saved
     ## Figure will NOT appear in R Enviroment
     ## pdf of the figure will be save in the designated outpath

  ### Google API key required for basemaps - insert your API below
    Google.API <- " **** Insert Google API key here**** "

Map.of.Nodes(Google.API)






