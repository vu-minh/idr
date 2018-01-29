module Update exposing (..)

import Draggable
import Msgs exposing (Msg(..), myDragConfig)
import Commands exposing (..)
import Models exposing (..)
import Plot.CircleGroup exposing (..)
import Plot.Scatter exposing (createScatter, getMovedPoints)
import Plot.LineChart exposing (createSeries)


{-| Big update function to handle all system messages
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ scatter, ready } as model) =
    case msg of
        {- Do embedding commands -}
        LoadDataset ->
            ( Models.initialModel, loadDataset )

        DatasetStatus status ->
            { model | debugMsg = status } ! []

        DoEmbedding ->
            ( model, doEmbedding model.current_it )

        EmbeddingResult dataStr ->
            updateNewData model dataStr

        {- Control server command -}
        PauseServer ->
            { model | ready = False } ! []

        ContinueServer ->
            -- if we wish to run the server `manually`
            -- do not set the `ready` flag to `True`
            ( { model | ready = True }, sendContinue model.current_it )

        ResetData ->
            ( Models.initialModel, sendReset )

        {- Client interact commands -}
        SendMovedPoints ->
            let
                movedPoints =
                    Plot.Scatter.getMovedPoints scatter
            in
                ( { model | ready = True }, sendMovedPoints movedPoints )

        {- Drag circle in scatter plot commands -}
        OnDragBy delta ->
            let
                newScatter =
                    { scatter | points = dragActiveBy delta scatter.points }
            in
                { model | scatter = newScatter } ! []

        StartDragging circleId ->
            let
                newScatter =
                    { scatter | points = startDragging circleId scatter.points }
            in
                { model | scatter = newScatter } ! []

        StopDragging ->
            let
                newScatter =
                    { scatter | points = stopDragging scatter.points }
            in
                { model | scatter = newScatter } ! []

        DragMsg dragMsg ->
            Draggable.update myDragConfig dragMsg model

        UpdateZoomFactor amount ->
            let
                newZoomFactor =
                    Result.withDefault 10.0 <| String.toFloat amount

                updatedScatter =
                    Plot.Scatter.createScatter model.rawData newZoomFactor
            in
                { model | zoomFactor = newZoomFactor, scatter = updatedScatter } ! []


{-| Util function to update new received data into model
-}
updateNewData : Model -> String -> ( Model, Cmd Msg )
updateNewData ({ ready, current_it } as model) dataStr =
    case decodeEmbeddingResult dataStr of
        Err msg ->
            Debug.log ("[ERROR]decodeEmbeddingResult:\n" ++ msg)
                ( Models.initialModel, Cmd.none )

        Ok embeddingResult ->
            let
                nextCommand =
                    if ready then
                        sendContinue (current_it + 1)
                    else
                        Cmd.none

                rawPoints =
                    embeddingResult.embedding

                seriesData =
                    embeddingResult.seriesData

                ahead =
                    Maybe.withDefault { name = "x", series = [] } (List.head seriesData)

                errorValues =
                    ahead.series

                --trustworthinesses =
                --    seriesData[1].trustworthinesses
                --statbilities =
                --    seriesData[2].stabilities
                --convergences =
                --    seriesData[3].convergences
            in
                ( { model
                    | current_it = current_it + 1
                    , rawData = rawPoints
                    , scatter = Plot.Scatter.createScatter rawPoints model.zoomFactor
                    , errorSeries = Plot.LineChart.createSeries errorValues

                    --, measureSeries = Plot.LineChart.createSeries trustworthinesses
                    --, stabilitySeries = Plot.LineChart.createSeries statbilities
                    --, convergenceSeries = Plot.LineChart.createSeries convergences
                  }
                , nextCommand
                )
