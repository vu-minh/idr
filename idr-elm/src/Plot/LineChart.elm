module Plot.LineChart exposing (viewLineChart)

{-| This module shows how to build a simple line and area chart using some of
the primitives provided in this library.
-}

import Svg exposing (..)
import Svg.Attributes exposing (..)
import Visualization.Axis as Axis exposing (defaultOptions)
import Visualization.List as List
import Visualization.Scale as Scale exposing (ContinuousScale)


--import Visualization.Scale.Linear as Linear exposing (Visualization.Scale.tickFormat)

import Visualization.Shape as Shape
import Common exposing (intToColor10Str)


w : Float
w =
    265.0


h : Float
h =
    170.0


padding : Float
padding =
    30.0


viewLineChart : String -> List (List Float) -> Svg msg
viewLineChart name series =
    let
        labels =
            String.split "," name

        yScale =
            series
                -- find max of each child list
                |> List.map (List.maximum >> Maybe.withDefault 0.0)
                -- max all
                |> List.maximum
                -- convert to real value
                |> Maybe.withDefault 0.0
                -- extend domain value
                |> (*) 1.1
                -- create tuple (0, maxX)
                |> (,) 0.0
                -- make f(a1, a2) as f(a2,a1)
                |> flip Scale.linear ( h - 2 * padding, 0.0 )

        xScale =
            series
                |> List.head
                |> Maybe.withDefault [ 0.0 ]
                |> List.length
                |> toFloat
                |> (*) 1.1
                |> (,) 0.0
                |> flip Scale.linear ( 0.0, w - 2 * padding )

        xAxis =
            Axis.axis { defaultOptions | orientation = Axis.Bottom, tickCount = 6 } xScale

        yAxis1 =
            -- static vertical axis
            Axis.axis { defaultOptions | orientation = Axis.Left, tickCount = 6 } yScale

        yAxis2 =
            -- dynamic vertical axis, just show lastest values of each series
            let
                newestValues =
                    series
                        |> List.map (List.reverse >> List.head >> Maybe.withDefault 0.0)
            in
                Axis.axis { defaultOptions | orientation = Axis.Left, ticks = Just (newestValues) } yScale

        transformToLineData idx value =
            Just
                ( Scale.convert xScale (toFloat idx)
                , Scale.convert yScale value
                )

        line points =
            points
                |> List.indexedMap transformToLineData
                |> Shape.line Shape.monotoneInXCurve

        drawLine idx points =
            Svg.path
                [ d (line points)
                , stroke (intToColor10Str idx)
                , strokeWidth "2px"
                , fill "none"
                ]
                []

        drawLabel idx label =
            g
                [ transform
                    ("translate("
                        ++ toString (Basics.round padding + idx * 140)
                        ++ ", "
                        ++ toString (padding - 10)
                        ++ ")"
                    )
                ]
                [ text_ [ fill (intToColor10Str idx) ] [ text label ] ]
    in
        svg [ width (toString w ++ "px"), height (toString h ++ "px") ]
            [ Svg.style [] [ text ".axis text {font: 8px sans-serif; }" ]
            , g [ transform ("translate(" ++ toString (padding - 1) ++ ", " ++ toString (h - padding) ++ ")") ]
                [ xAxis ]
            , g [ transform ("translate(" ++ toString (padding - 1) ++ ", " ++ toString padding ++ ")") ]
                [ yAxis1 ]
            , g [ transform ("translate(" ++ toString (w - padding - 1) ++ ", " ++ toString padding ++ ")") ]
                [ yAxis2 ]
            , g [ transform ("translate(" ++ toString padding ++ ", " ++ toString padding ++ ")"), class "series" ]
                (List.indexedMap drawLine series)
            , g [ fontFamily "sans-serif", fontSize "10" ]
                (List.indexedMap drawLabel labels)
            ]
