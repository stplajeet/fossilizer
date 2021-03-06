{-# LANGUAGE RecordWildCards, ViewPatterns #-}

module OBJ(
    Vertex(..), size, unit, normal,
    OBJ(..), showOBJ, readOBJ
    ) where

import Numeric
import Control.Arrow
import qualified Data.Map as Map
import Data.Maybe


---------------------------------------------------------------------
-- VERTEX LIBRARY

data Vertex = Vertex {x, y, z :: Double} deriving (Show,Eq,Ord)

instance Num Vertex where
    fromInteger = lift0 . fromInteger
    signum = lift0 . signum . size
    abs = lift1 abs
    negate = lift1 negate
    (-) = lift2 (-)
    (+) = lift2 (+)
    (*) = lift2 (*)

instance Fractional Vertex where
    fromRational = lift0 . fromRational
    (/) = lift2 (/)
    recip = lift1 recip

lift0 :: Double -> Vertex
lift0 v = Vertex v v v

lift1 :: (Double -> Double) -> Vertex -> Vertex
lift1 f v = Vertex (g x) (g y) (g z)
    where g sel = f $ sel v

lift2 :: (Double -> Double -> Double) -> Vertex -> Vertex -> Vertex
lift2 f v1 v2 = Vertex (g x) (g y) (g z)
    where g sel = f (sel v1) (sel v2)

normal :: Vertex -> Vertex -> Vertex -> Vertex
normal (Vertex x1 y1 z1) (Vertex x2 y2 z2) (Vertex x3 y3 z3) = Vertex
    ((y2-y1)*(z3-z1) - (y3-y1)*(z2-z1))
    ((z2-z1)*(x3-x1) - (x2-x1)*(z3-z1))
    ((x2-x1)*(y3-y1) - (x3-x1)*(y2-y1))


size :: Vertex -> Double
size (Vertex x y z) = sqrt (sqr x + sqr y + sqr z)
    where sqr v = v * v

unit :: Vertex -> Vertex
unit v | n == 0 = v
       | otherwise = v / fromRational (toRational n)
    where n = size v


---------------------------------------------------------------------
-- OBJ LIBRARY

data OBJ = Face {verticies :: [Vertex], normals :: [Vertex]}
         | MaterialFile FilePath
         | Material String
         | Group String

data S = S {vs :: Map.Map Vertex Int, vns :: Map.Map Vertex Int}

showOBJ :: [OBJ] -> [String]
showOBJ = showMany $ S Map.empty Map.empty
    where
        showMany s [] = []
        showMany s (f:fs) = showOne s f $ \s -> showMany s fs

        showOne s Face{..} k =
            showList showVertex s verticies $ \s ps ->
            showList showNormal s normals $ \s ns ->
            (unwords $ "f" : zipWith (++) ps (ns ++ repeat "")) : k s
        showOne s (MaterialFile x) k = ("mtllib " ++ x) : k s
        showOne s (Material x) k = ("usemtl " ++ x) : k s
        showOne s (Group x) k = ("g " ++ x) : k s

        showList showOne s [] k = k s []
        showList showOne s (p:ps) k = showOne s p $ \s i -> showList showOne s ps $ \s is -> k s (i:is)

        showVertex s@S{..} v@Vertex{..} k
            | Just i <- Map.lookup v vs = k s $ show i
            | otherwise = let i = Map.size vs + 1 in
                          (unwords ["v",shw x,shw y,shw z,'#':show i]) :
                          k s{vs = Map.insert v i vs} (show i)

        showNormal s@S{..} vn@Vertex{..} k
            | Just i <- Map.lookup vn vns = k s $ "//" ++ show i
            | otherwise = let i = Map.size vns + 1 in
                          (unwords ["vn",shw x,shw y,shw z, '#':show i]) :
                          k s{vns = Map.insert vn i vns} ("//" ++ show i)


shw x = showFFloat Nothing x ""
-- alternative much faster definition (x4 faster)
-- import qualified Data.Double.Conversion.Text as Text
-- import qualified Data.Text as Text
-- shw = Text.unpack . Text.toShortest


readOBJ :: [String] -> [OBJ]
readOBJ = f (Map.empty, Map.empty)
    where
        f s ((words -> x):xs)
            | "v":x <- x = f (first (addVertex x) s) xs
            | "vn":x <- x = f (second (addVertex x) s) xs
            | "f":x <- x = let ps = map (asPoint s) x
                           in Face (map fst ps) (mapMaybe snd ps) : f s xs
            | ('#':_):_ <- x = f s xs
            | [] <- x = f s xs
            | otherwise = error $ "Can't parse OBJ line: " ++ unwords x
        f s [] = []

        addVertex (map read -> [x,y,z]) mp = Map.insert (Map.size mp + 1) Vertex{..} mp

        asPoint (vs, vns) (break (== '/') -> (a,dropWhile (== '/') -> b)) =
            (vs Map.! read a, if null b then Nothing else Just $ vns Map.! read b)
