###################################################################################
## Kristina L Paxton
## April 26 2021
##
## Functions for crew to use for diagnostics and exploration of beep and node health data
##
###################################################################################



####### Function to import raw beep data and format ##########

# Function to import raw data for a particular date range
import.beeps <- function(INFILE, NODE.VERSION, RADIOID, TIMEZONE, START, END) {
  # set working directory where files can be found
  setwd(INFILE)
  
  # Define pattern of beep data
  beep_pattern <- '*raw-data*.*csv*'
  
  # makes a vector with the list of files that match specified pattern, full.names = F path not included, recursive = T searches within folders
  beep_files <- list.files(INFILE, pattern = beep_pattern, full.names = FALSE, recursive = TRUE)
  
  # Get dates from each file in the list 
  # file name starts with folder name of sensor station, then raw folder name, then file name (e.g. E8D5CC231B00/raw/CTT-E8D5CC231B00-raw-data.2020-06-25_061624.csv.gz)
  # so date is starts at 44th element and ends at 53
  list_dates <- as.Date(substr(beep_files, 44,53), format = "%Y-%m-%d")
  
  #Define start and end date to select from files
  start_range <- as.Date(START, format = "%Y-%m-%d")
  end_range <- as.Date(END,  format = "%Y-%m-%d")
  
  # select only the files that lie in the range of dates 
  beep_files_date <- beep_files[list_dates %in% seq(start_range, end_range, by = "1 day")]
  
  # import csv files in the list
  beep_data <- lapply(beep_files_date, read.csv, header = T, colClasses=c("NodeId"="character","TagId"="character"))
  
  # Defines the name of each element based on the outcome of substr which is base station name
  # Substr - extracts the sensor station name from beep_file list (each sensor station is 12 characters and is the start of the name)
  beep_data.names <- names(beep_data) <- substr(beep_files_date, 1,12)  # alternatively stringr::str_sub(beep_files, start = 1, end = 12)
  
  # count number of records imported
  count.import <- sum(sapply(beep_data,nrow))
  
  # Format Time column
  beep_data <- lapply(beep_data, transform, Time = as.POSIXct(Time,format="%Y-%m-%d %H:%M:%OS",tz = "UTC"))
  
  # Make Time local timezone
  beep_data <- lapply(beep_data, transform, Time.local = lubridate::with_tz(Time, tzone = TIMEZONE))
  
  # Add a column indicating the version of the nodes
  beep_data <- lapply(beep_data, transform, v = NODE.VERSION)
  
  # Format NodeId so all letters are capatilized
  beep_data <- lapply(beep_data, transform, NodeId = toupper(NodeId))
  
  # Keep only rows with TagId values in lookup table 
  beep_data <- lapply(beep_data, function(x) x[x$TagId %in% tags$TagId,])
  
  # count number of records removed
  count.ghosts <- count.import - sum(sapply(beep_data,nrow))
  
  # Keep only rows with specified RadioId (only 1 omni-anntenna)
  beep_data <- lapply(beep_data, function(x) x[x$RadioId %in% RADIOID,])     
  
  # count number of records removed
  count.RadioId <-  count.import - count.ghosts - sum(sapply(beep_data,nrow))
  
  # Keep only rows with NodeId values in lookup table 
  beep_data <- lapply(beep_data, function(x) x[x$NodeId %in% nodes$NodeId,])
  
  # count number of detections removed from Nodes not in the network
  count.nodes <-  count.import - count.ghosts - count.RadioId - sum(sapply(beep_data,nrow))
  
  # Merge all of elements of the list into a dataframe and add an column - SensorId - which indicates the Sensor Station name
  BeepMerge <- dplyr::bind_rows(beep_data, .id = "SensorId")
  
  # Make a dataframe with dates exclude to see if certain nodes are potentially malfunctioning
  BadDates <- BeepMerge %>%
    dplyr::filter(!(Time.local >= start_range & Time.local <= seq(end_range + 1, end_range + 1, by = "1 day")))
  
  # Filter local time so only requested dates are outputted
  # to include times past 00:00:00 needed to have end date = 1 day past end date specified
  BeepMerge <- BeepMerge %>%
    dplyr::filter(Time.local >= start_range & Time.local <= seq(end_range + 1, end_range + 1, by = "1 day"))
  
  # count number of detections removed with local times not in the network
  count.date <-  count.import - count.ghosts - count.RadioId - count.nodes - nrow(BeepMerge)
  
  # Remove rows with NA values
  # example for a list - beep_data <- lapply(beep_data,function(x) x[complete.cases(x),])
  BeepMerge <- BeepMerge[complete.cases(BeepMerge),]
  
  # count number of detections with NA
  count.NA <-  count.import - count.ghosts - count.RadioId - count.nodes - count.date - nrow(BeepMerge)
  
  # remove duplicate data (e.g. detected at multiple Sensor Stations)
  BeepMerge <- BeepMerge %>%
    dplyr::distinct(Time, TagId, NodeId, TagRSSI, .keep_all = T)
  
  # count number of duplicate rows
  count.duplicates <- count.import - count.ghosts - count.RadioId - count.nodes - count.date - count.NA - nrow(BeepMerge)
  
  # Format NodeId, TagId, and SensorId so that they are Factors
  BeepMerge$NodeId <- as.factor(BeepMerge$NodeId)
  BeepMerge$TagId <- as.factor(BeepMerge$TagId)
  BeepMerge$SensorId <- as.factor(BeepMerge$SensorId)
  
  # save beep data
  saveRDS(BeepMerge, paste0(outpath, "beep_data", "_", START, "_", END, ".rds"))
  
  # Make a list of data to output from function
  list <- list("beep_data" = BeepMerge, "beep.bad.dates" =  BadDates, "count.import" = count.import,"count.NA" =  count.NA, "count.RadioId" = count.RadioId,
               "count.date"  = count.date, "count.ghosts" =  count.ghosts, "count.nodes" = count.nodes, "count.duplicates" = count.duplicates)
  
  return(list) 
  
  
}



####### Function to import node health data and format ########

import.node.health <- function(INFILE, NODE.VERSION, RADIOID, TIMEZONE, START, END, LAT.LOWER, LAT.UPPER, LONG.LOWER, LONG.UPPER) {
  # set working directory where files can be found
  setwd(INFILE)
  
  # Define pattern of node data
  node_pattern <- '*node-health*.*csv*'
  
  # makes a vector with the list of files that match specified pattern, full.names = F path not included, recursive = T searches within folders
  node_files <- list.files(INFILE, pattern = node_pattern, full.names = FALSE, recursive = TRUE)
  
  # Get dates from each file in the list 
  # file name starts with folder name of sensor station, then raw folder name, then file name (e.g. E8D5CC231B00/node_health/CTT-E8D5CC231B00-node-health.2020-06-25_061624.csv.gz)
  # so date is starts at 55th element and ends at 66
  list_dates <- as.Date(substr(node_files, 55,66), format = "%Y-%m-%d")
  
  #Define start and end date to select from files
  start_range <- as.Date(START, format = "%Y-%m-%d")
  end_range <- as.Date(END,  format = "%Y-%m-%d")
  
  # select only the files that lie in the range of dates - subtract 1 day from the start to account for datetime in UTC time
  node_files_date <- node_files[list_dates %in% seq(start_range - 1, end_range, by = "1 day")]
  
  # import csv files in the list
  node_import <- lapply(node_files_date, read.csv, header = T, colClasses=c("NodeId"="character"))
  
  # Defines the name of each element based on the outcome of substr
  # Substr - extracts the sensor station name from Node_file list (each sensor station is 12 characters and is the start of the name)
  node_import.names <- names(node_import) <- stringr::str_sub(node_files_date, start = 1, end = 12) # alternativly with base r -  substr(node_files, start = 1, stop = 12)
  
  # count number of records imported
  count.import <- sum(sapply(node_import,nrow))
  
  # Format Time column
  node_import <- lapply(node_import, transform, Time = as.POSIXct(Time,format="%Y-%m-%d %H:%M:%OS",tz = "UTC"))
  
  # Make Time local timezone
  node_import <- lapply(node_import, transform, Time.local = lubridate::with_tz(Time, tzone = TIMEZONE))
  
  # Format RecorderAt column
  node_import <- lapply(node_import, transform, RecordedAt = as.POSIXct(RecordedAt,format="%Y-%m-%d %H:%M:%OS",tz = "UTC")) 
  
  # Add a column indicating the version of the nodes
  node_import <- lapply(node_import, transform, v = NODE.VERSION)
  
  # Format NodeId so all letters are capatilized
  node_import <- lapply(node_import, transform, NodeId = toupper(NodeId))
  
  # Keep only rows with NodeId values in lookup table 
  node_import <- lapply(node_import, function(x) x[x$NodeId %in% nodes$NodeId,])
  
  # count number of detections removed from Nodes not in the network
  count.nodes <- count.import - sum(sapply(node_import,nrow))
  
  # Remove rows with NA values
  node_import <- lapply(node_import,function(x) x[complete.cases(x),])
  
  # count number of detections removed from Nodes not in the network
  count.NA <- count.import - count.nodes - sum(sapply(node_import,nrow))
  
  # Merge all of elements of the list into a dataframe and add an column - SensorId - which indicates the Sensor Station name
  NodeMerge <- dplyr::bind_rows(node_import, .id = "SensorId")
  
  # Filter local time so only requested dates are outputted
  # to include times past 00:00:00 needed to have end date = 1 day past end date specified
  NodeMerge <- NodeMerge %>%
    dplyr::filter(Time.local >= start_range & Time.local <= seq(end_range + 1, end_range + 1, by = "1 day"))
  
  # count number of detections removed with local times not in the network
  count.date <- count.import - count.nodes - count.NA - nrow(NodeMerge)
  
  # Make a new data frame for node health data with outlier lat and long
  NodeBadLocations <- NodeMerge %>%
    dplyr::filter(Longitude < LONG.LOWER | Longitude > LONG.UPPER) %>%
    dplyr::filter(Latitude < LAT.LOWER | Latitude > LAT.UPPER)
  
  # Remove outlier lat and long from NodeMerge dataframe
  NodeMerge <- NodeMerge %>%
    dplyr::filter(Longitude > LONG.LOWER & Longitude < LONG.UPPER) %>%
    dplyr::filter(Latitude > LAT.LOWER & Latitude < LAT.UPPER)
  
  # Format NodeId and SensorId so that they are Factors
  NodeMerge$NodeId <- as.factor(NodeMerge$NodeId)
  NodeMerge$SensorId <- as.factor(NodeMerge$SensorId)
  
  # save data
  saveRDS(NodeMerge, paste0(outpath, "node_data_", START, "_", END, ".rds"))
  
  # Make a list of data to output from function
  list <- list("node_data" = NodeMerge, "version" = NODE.VERSION, "count.import" = count.import,"count.NA" =  count.NA, 
               "count.date"  = count.date, "count.nodes" = count.nodes, "Nodes_Bad.Locations" = NodeBadLocations)
  
  return(list) 
  
}




######### Function to make plot of Node RSSI by Time Stamp with different colors for Base Station #########

Node.RSSI.Plot <- function(x) {
  p <- ggplot(data = x, aes(x = Time.local, y = NodeRSSI, group=SensorId, colour=SensorId)) +
  geom_point() + 
  ggforce::facet_wrap_paginate(~NodeId, nrow = 4, ncol = 4, page = NULL)

# Determine how many pages are needed to plot information with 4 rows and 4 columns per page
required_n_pages <- n_pages(p)

# loop over required pages and save
pdf(file = paste0(outpath, "NodeRSSI_ByDate_", START, "_", END, ".pdf"), width = 16, height = 12)

for(i in 1:required_n_pages){
  print(ggplot(data = x, aes(x = Time.local, y = NodeRSSI, group=SensorId, colour=SensorId)) +
          geom_point() + 
          geom_hline(yintercept = -95) +
          ggforce::facet_wrap_paginate(~NodeId, nrow = 4, ncol = 4, page = i))
  
}

dev.off()

}



######## Function to make plot of Node Battery Voltage by Time Stamp with different colors for Base Station ########

Node.Battery.Plot <- function(x) {
  q <- ggplot(data = x, aes(x = Time.local, y = Battery, group=SensorId, colour=SensorId)) +
    geom_point() + 
    ggforce::facet_wrap_paginate(~NodeId, nrow = 4, ncol = 4, page = NULL)
  
  # Determine how many pages are needed to plot information with 4 rows and 4 columns per page
  required_n_pages <- n_pages(q)


pdf(file = paste0(outpath, "NodeBattery_ByDate_", START, "_", END, ".pdf"), width = 16, height = 12)

# Make plot of Node Battery level by Time Stamp with different colors for Base Station
for(i in 1:required_n_pages){
  print(ggplot(data = x, aes(x = Time.local, y = Battery, group=SensorId, colour=SensorId)) +
          geom_point() + 
          geom_hline(yintercept = 4) +
          ggforce::facet_wrap_paginate(~NodeId, nrow = 4, ncol = 4, page = i, scales = "free_y"))
}

dev.off()

}





########## Function to calculate avg location of each node and indicate nodes not reporting to CTT #########

# Calculate average lat long for each node

Node.Avg.Location <- function(x) {
  node.loc.summary <- x %>%
    dplyr::group_by(NodeId) %>%
    dplyr::summarise(lng = mean(Longitude),
                     lat = mean(Latitude))

# save data
write.csv(node.loc.summary, paste0(outpath, "Nodes_Avg.Location_", START, "_", END, ".csv"), row.names = F)

missing.nodes <- nodes %>%
  dplyr::anti_join(node.loc.summary) %>%
  dplyr::select(NodeId) %>%
  dplyr::mutate(Status = "missing_ML")

write.csv(missing.nodes, paste0(outpath, "Missing.Nodes_",  START, "_", END, ".csv"), row.names = F)

return(node.loc.summary)

}





##### Function to make a pdf file containing a map of Node and Base Station Locations #############


Map.of.Nodes <- function(Google.API) { 
  
# Google API key required for basemaps
ggmap::register_google(key = Google.API)

  
# Define the center of network array based on current data
  centerLng <- min(node.loc.summary$lng) + ((max(node.loc.summary$lng) - min(node.loc.summary$lng))/2)
  centerLat <-min(node.loc.summary$lat) + ((max(node.loc.summary$lat) - min(node.loc.summary$lat))/2)
  
# base map from google maps
ph_basemap <- ggmap::get_googlemap(center = c(lon = centerLng, lat = centerLat),
                                                      zoom=ZOOM, # map zoom; an integer from 3 (continent) to 21 (building), default value 10 (city)
                                                      maptype = "satellite")

map <- ggmap(ph_basemap) +
  geom_point(aes(x = lng, y = lat), color = "red", size = 3, data = node.loc.summary) +
  geom_text(aes(x = lng, y = lat, label = NodeId), color = "yellow", size = 3, hjust = 1, vjust = 1.5, data = node.loc.summary) +
  geom_point(aes(x = lng, y = lat), color = "green", shape = 15, size = 3, data = base) +
  geom_text(aes(x = lng, y = lat, label = BaseId), color = "orange", size = 3.5, hjust = 1, vjust = -1.5, data = base)


pdf(paste0(outpath, "Node.Locations_Sat.Base.Map_", START, "_", END, ".pdf"), width = 16, height = 12)
print(map)

dev.off()

}


