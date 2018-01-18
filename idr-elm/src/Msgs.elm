module Msgs exposing (..)

import Draggable
import Draggable.Events exposing (onDragBy, onDragStart)
import Common exposing (CircleId)


type Msg
    = LoadDataset -- [send] load dataset (TODO add dataset name)
    | DatasetStatus String -- [receive] server response dataset info
    | DoEmbedding -- [send] do embedding
    | EmbeddingResult String -- [receive] the intermediate result
    | PauseServer -- [send] pause server
    | ContinueServer -- [send] unpause server
    | SendMovedPoints -- [send] send moved points to server
    | ResetData -- [send] send reset data command
    | DragMsg (Draggable.Msg CircleId) -- draggable message
    | StartDragging CircleId
    | OnDragBy Draggable.Delta
    | StopDragging


myDragConfig : Draggable.Config CircleId Msg
myDragConfig =
    Draggable.customConfig
        [ onDragBy OnDragBy
        , onDragStart StartDragging
        ]
