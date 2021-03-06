#' Get Point Elevation
#' 
#' Several web services provide access to point elevations.  This function 
#' provides access to one of those.  Currently it uses the USGS Elevation Point 
#' Query Service (US Only).  The function accepts a \code{data.frame} of x 
#' (long) and y (lat) or a \code{SpatialPoints}/\code{SpatialPointsDataFame} as 
#' input.  A SpatialPointsDataFrame is returned with elevation as an added 
#' \code{data.frame}.
#' 
#' @param locations Either a \code{data.frame} with x (e.g. longitude) as the 
#'                  first column and y (e.g. latitude) as the second column or a 
#'                  \code{SpatialPoints}/\code{SpatialPointsDataFrame}.  
#'                  Elevation for these points will be returned.
#' @param prj A PROJ.4 string defining the projection of the locations argument. 
#'            If a \code{SpatialPoints} or \code{SpatialPointsDataFrame} is 
#'            provided, the PROJ.4 string will be taken from that.  This 
#'            argument is required for a \code{data.frame} of locations.
#' @param src A character indicating which API to use, currently only "epqs". 
#'            The "epqs" source is relatively slow for larger numbers of points 
#'            (e.g. > 500). 
#' @param ... Additional arguments passed to get_epqs
#' @return Function returns a \code{SpatialPointsDataFrame} in the projection 
#'         specified by the \code{prj} argument.
#' @export
#' @examples
#' \dontrun{
#' mt_wash <- data.frame(x = -71.3036, y = 44.2700)
#' mt_mans <- data.frame(x = -72.8145, y = 44.5438)
#' mts <- rbind(mt_wash,mt_mans)
#' ll_prj <- "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
#' mts_sp <- sp::SpatialPoints(sp::coordinates(mts), 
#'                             proj4string = sp::CRS(ll_prj)) 
#' get_elev_point(locations = mt_wash, prj = ll_prj)
#' get_elev_point(locations = mt_wash, units="feet", prj = ll_prj)
#' get_elev_point(locations = mt_wash, units="meters", prj = ll_prj)
#' get_elev_point(locations = mts_sp)
#' }
get_elev_point <- function(locations, prj = NULL, src = c("epqs"), ...){
  src <- match.arg(src)
  # Check location type and if sp, set prj.  If no prj (for either) then error
  locations <- loc_check(locations,prj)
  prj <- sp::proj4string(locations)
  
  # Pass of reprojected to epqs or mapzen to get data as spatialpointsdataframe
  if (src == "epqs"){
    locations_prj <- get_epqs(locations, ...)
  }
  # Re-project back to original and return
  locations <- sp::spTransform(locations_prj,sp::CRS(prj))
  if(length(list(...)) > 0){ 
    if(names(list(...)) %in% "units" & list(...)$units == "feet"){
      locations$elev_units <- rep("feet", nrow(locations))
    } else {
      locations$elev_units <- rep("meters", nrow(locations))
    }
  } else {
    locations$elev_units <- rep("meters", nrow(locations))
  }
  locations
}

#' Get point elevation data from the USGS Elevation Point Query Service
#' 
#' Function for accessing elevation data from the USGS epqs
#' 
#' @param locations A SpatialPointsDataFrame of the location(s) for which you 
#'                  wish to return elevation. The first column is Longitude and 
#'                  the second column is Latitude.  
#' @param units Character string of either meters or feet. Only works for 'epqs'
#' @return a SpatialPointsDataFrame with elevation added to the data slot
#' @export
#' @keywords internal
get_epqs <- function(locations, units = c("meters","feet")){
  base_url <- "http://ned.usgs.gov/epqs/pqs.php?"
  if(match.arg(units) == "meters"){
    units <- "Meters"
  } else if(match.arg(units) == "feet"){
    units <- "Feet"
  }
  # Re-project locations to dd
  
  locations <- sp::spTransform(locations,
                                   sp::CRS("+proj=longlat +ellps=GRS80 +datum=NAD83 +no_defs"))
  units <- paste0("&units=",units)
  pb <- progress::progress_bar$new(format = " Accessing point elevations [:bar] :percent",
                                   total = nrow(locations), clear = FALSE, 
                                   width= 60)
  for(i in seq_along(locations[,1])){
    x <- sp::coordinates(locations)[i,1]
    y <- sp::coordinates(locations)[i,2]
    loc <- paste0("x=",x, "&y=", y)
    url <- paste0(base_url,loc,units,"&output=json")
    resp <- httr::GET(url)
    if (httr::http_type(resp) != "application/json") {
      stop("API did not return json", call. = FALSE)
    } 
    resp <- jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8"), 
                               simplifyVector = FALSE
                                )
    locations$elevation[i] <- as.numeric(resp[[1]][[1]]$Elevation)
    pb$tick()
    Sys.sleep(1 / 100)
  }
  
  locations
}
