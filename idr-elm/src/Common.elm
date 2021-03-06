module Common exposing (..)

import List.Extra exposing (maximumBy, minimumBy)
import Array
import Color exposing (..)
import Visualization.Scale exposing (category20a, category10)
import Math.Vector2 as Vector2 exposing (Vec2, getX, getY)
import Dict exposing (..)


type DatasetType
    = NoType
    | Image
    | Table
    | Text


datasets =
    Dict.fromList
        [ ( "", ( NoType, "--Select dataset--" ) )
        , ( "COUNTRY1999", ( Table, "Country Indicators 1999" ) )
        , ( "COUNTRY2013", ( Table, "Country Indicators 2013" ) )
        , ( "COUNTRY2014", ( Table, "Country Indicators 2014" ) )
        , ( "COUNTRY2015", ( Table, "Country Indicators 2015" ) )
        , ( "CARS04", ( Table, "Cars and Trucks 2004" ) )
        , ( "BREAST-CANCER95", ( Table, "Breast Cancer Wisconsin (Diagnostic)" ) )
        , ( "DIABETES", ( Table, "Pima Indians Diabetes" ) )
        , ( "MPI", ( Table, "Multidimensional Poverty Measures" ) )
        , ( "INSURANCE", ( Table, "US Insurance Cost" ) )
        , ( "FIFA18", ( Table, "Fifa 18 Players (top 2000)" ) )
        , ( "FR_SALARY", ( Table, "French salaries per town (top 2000)" ) )
        , ( "MNIST-SMALL", ( Image, "MNIST mini" ) )
        , ( "MNIST", ( Image, "MNIST full (sample 2000)" ) )
        , ( "COIL20", ( Image, "COIL-20" ) )
        , ( "WIKI-FR-1K", ( Text, "Top 1000 words in Wiki-French" ) )
        , ( "WIKI-FR-3K", ( Text, "Top 3000 words in Wiki-French" ) )
        , ( "WIKI-EN-1K", ( Text, "Top 1000 words in Wiki-English" ) )
        , ( "WIKI-EN-3K", ( Text, "Top 3000 words in Wiki-English" ) )
        ]


getDatasetType : String -> DatasetType
getDatasetType datasetName =
    Dict.get datasetName datasets
        |> Maybe.withDefault ( NoType, "" )
        |> Tuple.first


isImageDataset : String -> Bool
isImageDataset datasetName =
    Image == getDatasetType datasetName


getImageSize : String -> Float
getImageSize datasetName =
    case datasetName of
        "MNIST" ->
            16

        "MNIST-SMALL" ->
            8

        _ ->
            0


type alias CircleId =
    String


type alias PlotConfig =
    { width : Float
    , height : Float
    , padding : Float
    , circleRadius : Float
    , selectionRadius : Float
    , minCircleRadius : Float
    , maxCircleRadius : Float
    , fixedRadius : Bool
    , autoZoom : Bool
    , zoomFactor : Float
    , nNeighbors : Int
    , showImage : Bool
    , showLabel : Bool
    , showColor : Bool
    , showAxes : Bool
    , center : Vec2
    , datasetName : String
    }


plotConfig : PlotConfig
plotConfig =
    { width = 820.0
    , height = 680.0
    , padding = 30.0
    , circleRadius = 5
    , selectionRadius = 0
    , minCircleRadius = 3
    , maxCircleRadius = 8
    , fixedRadius = False
    , autoZoom = False
    , zoomFactor = 30.0
    , nNeighbors = 50
    , showImage = True
    , showLabel = False
    , showColor = False
    , showAxes = False
    , center = Vector2.vec2 0 0
    , datasetName = "MNIST-SMALL"
    }


type alias Point =
    { id : String
    , x : Float
    , y : Float
    , z : Float
    , label : String
    , text : String
    , fixed : Bool
    }


{-| Data structure for storing a series data for all iterations, including:

  - `name`: readable name of series data, e.g. "Errors" or "PIVE Measures"
  - `series`: a list of series data, each series data is an array of float

-}
type alias SeriesData =
    { name : String
    , series : List (List Float)
    }


emptySeriesData =
    { name = "", series = [] }


{-| Data structure that the server returns after each iteration, including:

  - `embedding`: a list of new position of embedded points
  - `seriesData`: a list of `SeriesData` for tracing errors, measurements, ...

-}
type alias EmbeddingResult =
    { embedding : List Point
    , seriesData : List SeriesData
    , distances : List (List Float)
    , neighbors : List (List String)
    }


{-| Data structure containing the pairwise distance of the original dataset
-}
type alias DatasetInfo =
    { distances : List (List Float)
    , neighbors : List (List String)
    , importantPoints : List String
    , infoMsg : String
    }


{-| <http://htmlcolorcodes.com/>
<http://package.elm-lang.org/packages/gampleman/elm-visualization/latest/Visualization-Scale>
-}
intToColor10Str : Int -> String
intToColor10Str idx =
    category10
        |> Array.fromList
        |> Array.get (idx % 10)
        |> Maybe.withDefault Color.blue
        |> flip colorToString 1.0


labelToColorStr : String -> Float -> String
labelToColorStr label alphaFactor =
    let
        labelId =
            label
                |> String.toInt
                |> Result.toMaybe
                |> Maybe.withDefault -1
    in
        category20a
            |> Array.fromList
            |> Array.get labelId
            |> Maybe.withDefault Color.black
            |> flip colorToString alphaFactor


colorToString : Color -> Float -> String
colorToString color alphaFactor =
    let
        { red, green, blue, alpha } =
            toRgb color
    in
        "rgba("
            ++ (red |> toString)
            ++ ","
            ++ (green |> toString)
            ++ ", "
            ++ (blue |> toString)
            ++ ","
            ++ ((alphaFactor * alpha) |> toString)
            ++ ")"


{-| Util function to get min/max value of field (x, y, z) in a list of points
-}
minField field points =
    case minimumBy field points of
        Nothing ->
            0

        Just p ->
            field p


maxField field points =
    case maximumBy field points of
        Nothing ->
            0

        Just p ->
            field p
