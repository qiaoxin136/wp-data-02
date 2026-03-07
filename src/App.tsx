import type { ChangeEvent, SyntheticEvent } from "react";
import { useEffect, useState, useMemo } from "react";
import type { Schema } from "../amplify/data/resource";
import { checkLoginAndGetName } from "./utils/AuthUtils";
import { useAuthenticator } from '@aws-amplify/ui-react';
import { generateClient } from "aws-amplify/data";
import "@aws-amplify/ui-react/styles.css";
import { uploadData, remove } from "aws-amplify/storage";
import { StorageImage } from "@aws-amplify/ui-react-storage"; //Hong

import { MapboxOverlay, MapboxOverlayProps } from "@deck.gl/mapbox/typed";
import { PickingInfo } from "@deck.gl/core/typed";
import { PathStyleExtension } from "@deck.gl/extensions/typed";
import "@aws-amplify/ui-react/styles.css";

import "maplibre-gl/dist/maplibre-gl.css"; // Import maplibre-gl styles

import {
  Map,
  useControl,
  Popup,
  Marker,
  NavigationControl,
  GeolocateControl,
} from "react-map-gl";

import maplibregl from "maplibre-gl";

import "mapbox-gl/dist/mapbox-gl.css";


import {
  Input,
  Flex,
  Button,
  Table,
  TableBody,
  TableHead,
  TableCell,
  TableRow,
  ThemeProvider,
  Theme,
  Divider,
  Tabs,
  SelectField,
  ScrollView,
  CheckboxField,
  // TextField,
} from "@aws-amplify/ui-react";

import "@aws-amplify/ui-react/styles.css";

import "@aws-amplify/ui-react/styles.css";
import { GeoJsonLayer } from "@deck.gl/layers/typed";
//import { IconLayer } from "@deck.gl/layers/typed";
import { MVTLayer } from "@deck.gl/geo-layers/typed";
import { TextLayer } from "@deck.gl/layers/typed";

const client = generateClient<Schema>();

type ByCategory = Record<string, { count: number; sum: number }>;


const theme: Theme = {
  name: "table-theme",
  tokens: {
    components: {
      table: {
        row: {
          hover: {
            backgroundColor: { value: "{colors.blue.20}" },
          },

          striped: {
            backgroundColor: { value: "{colors.orange.10}" },
          },
        },

        header: {
          color: { value: "{colors.blue.80}" },
          fontSize: { value: "{fontSizes.x3}" },
          borderColor: { value: "{colors.blue.20}" },
        },

        data: {
          fontWeight: { value: "{fontWeights.semibold}" },
        },
      },
    },
  },
};

type DataT = {
  type: "Feature";
  id: number;
  geometry: {
    type: "Point";
    coordinates: [number, number, number];
  };
  properties: {
    track: number;
    type: string;
    status: string;
    date: string;
    time: string;
    id: string;
  };
};

type SelectOption = {
  value: string;
  label: string;
};

const AIR_PORTS =
  "https://drd977abuk.execute-api.us-east-1.amazonaws.com/test/getData";



// Hong's addition
export type CustomEvent = {
  target: HTMLInputElement
}
// Hong's addition end

const MAP_STYLE = "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json";
// "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json";

function DeckGLOverlay(
  props: MapboxOverlayProps & {
    interleaved?: boolean;
  }
) {
  const overlay = useControl<MapboxOverlay>(() => new MapboxOverlay(props));
  // @ts-ignore
  overlay && overlay.setProps(props);
  return null;
}



function App() {

  const { signOut } = useAuthenticator();
  //const client = generateClient<Schema>();
  const [location, setLocation] = useState<Array<Schema["Location"]["type"]>>([]);

  const [date, setDate] = useState("");
  const [time, setTime] = useState("");
  //const [report, setReport] = useState("");
  const [track, setTrack] = useState<number>(0);
  const [type, setType] = useState<string>("water");
  const [diameter, setDiameter] = useState<number>(0);
  const [length, setLength] = useState<number>(0);
  const [userName, setUserName] = useState<string>();
  const [description, setDescription] = useState<string>("");
  const [lat, setLat] = useState(0);
  const [lng, setLng] = useState(0);
  const [placePhotos, setPlacePhotos] = useState<File[]>([]);

  const [tab, setTab] = useState("1");

  const [clickInfo, setClickInfo] = useState<DataT>();
  const [showPopup, setShowPopup] = useState<boolean>(true);
  const [checked, setChecked] = useState<boolean>(false);

  const { totalSum, totalCount, byCategory } = useExpenseAggregates();

  const options: SelectOption[] = [
    { value: 'water', label: 'Water' },
    { value: 'wastewater', label: 'Wastewater' },
    { value: 'stormwater', label: 'Stormwater' },
    { value: 'pavement', label: 'Pavement' }
  ];

  console.log(AIR_PORTS);

  const layers = [


    new GeoJsonLayer({
      id: "history",
      data: AIR_PORTS,
      // Styles
      filled: true,
      pointType: "circle",
      // iconAtlas:
      //   "https://raw.githubusercontent.com/visgl/deck.gl-data/master/website/icon-atlas.png",
      // iconMapping:
      //   "https://raw.githubusercontent.com/visgl/deck.gl-data/master/website/icon-atlas.json",
      // getIcon: () => "marker",
      // getIconSize: 5,
      // getIconColor: (d: any) =>
      //   d.properties.status === "true"
      //     ? [80, 200, 120, 255]
      //     : [220, 20, 60, 255],
      // getIconAngle: 0,
      // iconSizeUnits: "meters",
      // iconSizeScale: 3,
      // iconSizeMinPixels: 6,
      // pointRadiusMinPixels: 2,
      // pointRadiusScale: 5,
      getFillColor: (d: any) =>
        d.properties.type === "water"
          ? [0, 0, 139, 255]
          : d.properties.type === "wastewater"
            ? [9, 121, 105, 255]
            : d.properties.type === "stormwater"
              ? [204, 85, 0, 255]
              : [113, 121, 126, 255],
      getText: (d: any) => d.properties.date,
      getTextColor: [0, 0, 0, 255],
      getTextSize: 32,
      // getPointRadius: (f) => 11 - f.properties.scalerank,
      //getFillColor: (d:any)=>(d.properties.status==="true" ?[220, 20, 60, 255]:[34, 35,25,255]),
      // Interactive props
      pickable: true,
      autoHighlight: true,
    }),

    new TextLayer({
      id: 'text-layer',
      data: AIR_PORTS,
      pickable: false,
      getPosition: d => d.geometry.coordinates,
      getText: d => d.data,
      getSize: 16,
      getAngle: 0,
      getTextAnchor: 'middle',
      getAlignmentBaseline: 'center',
      getColor: [255, 255, 255]
    }),

    // new MVTLayer({
    //   id: "lateral",
    //   data: `https://a.tiles.mapbox.com/v4/hazensawyer.0t8hy4di/{z}/{x}/{y}.vector.pbf?access_token=pk.eyJ1IjoiaGF6ZW5zYXd5ZXIiLCJhIjoiY2xmNGQ3MDgyMTE3YjQzcnE1djRpOGVtNiJ9.U06GItbSVWFTsvfg9WwQWQ`,

    //   minZoom: 0,
    //   maxZoom: 23,
    //   getLineColor: [169, 169, 169, 255],

    //   getFillColor: [140, 170, 180],
    //   getLineWidth: 1,

    //   lineWidthMinPixels: 1,
    //   pickable: true,
    //   visible: checked,
    // }),

    // new MVTLayer({
    //   id: "gravity-public-pipe",
    //   data: `https://a.tiles.mapbox.com/v4/hazensawyer.04mlahe9/{z}/{x}/{y}.vector.pbf?access_token=pk.eyJ1IjoiaGF6ZW5zYXd5ZXIiLCJhIjoiY2xmNGQ3MDgyMTE3YjQzcnE1djRpOGVtNiJ9.U06GItbSVWFTsvfg9WwQWQ`,

    //   minZoom: 0,
    //   maxZoom: 23,
    //   getLineColor: (f: any) =>
    //     f.properties.DIAMETER < 11
    //       ? [0, 163, 108, 255]
    //       : f.properties.DIAMETER < 17
    //         ? [218, 112, 214, 255]
    //         : f.properties.DIAMETER < 25
    //           ? [93, 63, 211, 255]
    //           : f.properties.DIAMETER < 31
    //             ? [191, 64, 191, 255]
    //             : [238, 75, 43, 255],
    //   getFillColor: [140, 170, 180],
    //   getLineWidth: (f: any) =>
    //     f.properties.DIAMETER < 7
    //       ? 1
    //       : f.properties.DIAMETER < 11
    //         ? 3
    //         : f.properties.DIAMETER < 17
    //           ? 5
    //           : f.properties.DIAMETER < 25
    //             ? 7
    //             : f.properties.DIAMETER < 31
    //               ? 9
    //               : 11,

    //   lineWidthMinPixels: 1,
    //   pickable: true,
    //   visible: checked,
    // }),

    // new MVTLayer({
    //   id: "gravity-private-pipe",
    //   data: `https://a.tiles.mapbox.com/v4/hazensawyer.dhp8w8ur/{z}/{x}/{y}.vector.pbf?access_token=pk.eyJ1IjoiaGF6ZW5zYXd5ZXIiLCJhIjoiY2xmNGQ3MDgyMTE3YjQzcnE1djRpOGVtNiJ9.U06GItbSVWFTsvfg9WwQWQ`,

    //   minZoom: 0,
    //   maxZoom: 23,
    //   getLineColor: (f: any) =>
    //     f.properties.DIAMETER < 11
    //       ? [0, 163, 108, 255]
    //       : f.properties.DIAMETER < 17
    //         ? [218, 112, 214, 255]
    //         : f.properties.DIAMETER < 25
    //           ? [93, 63, 211, 255]
    //           : f.properties.DIAMETER < 31
    //             ? [191, 64, 191, 255]
    //             : [238, 75, 43, 255],

    //   getFillColor: [140, 170, 180],
    //   getLineWidth: (f: any) =>
    //     f.properties.DIAMETER < 7
    //       ? 1
    //       : f.properties.DIAMETER < 11
    //         ? 3
    //         : f.properties.DIAMETER < 17
    //           ? 5
    //           : f.properties.DIAMETER < 25
    //             ? 7
    //             : f.properties.DIAMETER < 31
    //               ? 9
    //               : 11,

    //   lineWidthMinPixels: 1,
    //   pickable: true,
    //   visible: checked,
    // }),

    // new MVTLayer({
    //   id: "fmpipe",
    //   data: `https://a.tiles.mapbox.com/v4/hazensawyer.4hfx5po8/{z}/{x}/{y}.vector.pbf?access_token=pk.eyJ1IjoiaGF6ZW5zYXd5ZXIiLCJhIjoiY2xmNGQ3MDgyMTE3YjQzcnE1djRpOGVtNiJ9.U06GItbSVWFTsvfg9WwQWQ`,

    //   minZoom: 0,
    //   maxZoom: 23,
    //   getLineColor: (f: any) =>
    //     f.properties.DIAMETER < 10
    //       ? [128, 0, 32, 255]
    //       : f.properties.DIAMETER < 20
    //         ? [233, 116, 81, 255]
    //         : [255, 195, 0, 255],
    //   getFillColor: [140, 170, 180],
    //   getLineWidth: (f: any) =>
    //     f.properties.DIAMETER < 7
    //       ? 1
    //       : f.properties.DIAMETER < 11
    //         ? 3
    //         : f.properties.DIAMETER < 17
    //           ? 4
    //           : f.properties.DIAMETER < 25
    //             ? 5
    //             : f.properties.DIAMETER < 31
    //               ? 6
    //               : 7,

    //   lineWidthMinPixels: 1,
    //   pickable: true,
    //   visible: checked,
    // }),

    // new MVTLayer({
    //   id: "mh",
    //   data: `https://a.tiles.mapbox.com/v4/hazensawyer.56zc2nx5/{z}/{x}/{y}.vector.pbf?access_token=pk.eyJ1IjoiaGF6ZW5zYXd5ZXIiLCJhIjoiY2xmNGQ3MDgyMTE3YjQzcnE1djRpOGVtNiJ9.U06GItbSVWFTsvfg9WwQWQ`,
    //   minZoom: 15,
    //   maxZoom: 23,
    //   filled: true,
    //   getIconAngle: 0,
    //   getIconColor: [0, 0, 0, 255],
    //   getIconPixelOffset: [-2, 2],
    //   getIconSize: 3,
    //   // getText: (f) => f.properties.FACILITYID,
    //   getPointRadius: 2,
    //   getTextAlignmentBaseline: "center",
    //   getTextAnchor: "middle",
    //   getTextAngle: 0,
    //   getTextBackgroundColor: [0, 0, 0, 255],
    //   getTextBorderColor: [0, 0, 0, 255],
    //   getTextBorderWidth: 0,
    //   getTextColor: [0, 0, 0, 255],
    //   getTextPixelOffset: [-12, -12],
    //   getTextSize: 20,
    //   pointRadiusMinPixels: 2,

    //   // getPointRadius: (f) => (f.properties.PRESSURE < 45 ? 6 : 3),
    //   getFillColor: [255, 195, 0, 255],
    //   // Interactive props
    //   pickable: true,
    //   visible: checked,
    //   autoHighlight: true,
    //   // ...choice,
    //   // pointRadiusUnits: "pixels",
    //   pointType: "circle+text",
    // }),

    new MVTLayer({
      id: "wMain",
      data: `https://a.tiles.mapbox.com/v4/hazensawyer.5764gcxp/{z}/{x}/{y}.vector.pbf?access_token=pk.eyJ1IjoiaGF6ZW5zYXd5ZXIiLCJhIjoiY2xmNGQ3MDgyMTE3YjQzcnE1djRpOGVtNiJ9.U06GItbSVWFTsvfg9WwQWQ`,

      minZoom: 0,
      maxZoom: 23,
      getLineColor: [31, 81, 255, 255],
      opacity: 0.5,   
      getFillColor: [140, 170, 180],
      getLineWidth: 0.2,
      lineWidthMinPixels: 1,
      getDashArray: [10, 8],
      dashJustified: true,
      dashGapPickable: true,
      extensions: [new PathStyleExtension({ dash: true })],
      pickable: true,
      visible: checked,
    }),

    new MVTLayer({
      id: "sGravity",
      data: `https://a.tiles.mapbox.com/v4/hazensawyer.54mpxvz3/{z}/{x}/{y}.vector.pbf?access_token=pk.eyJ1IjoiaGF6ZW5zYXd5ZXIiLCJhIjoiY2xmNGQ3MDgyMTE3YjQzcnE1djRpOGVtNiJ9.U06GItbSVWFTsvfg9WwQWQ`,

      minZoom: 0,
      maxZoom: 23,
      getLineColor: [50, 205, 50, 255],
      opacity: 0.5,    
      getFillColor: [140, 170, 180],
      getLineWidth: 0.2,
      lineWidthMinPixels: 1,
      getDashArray: [10, 8],
      dashJustified: true,
      dashGapPickable: true,
      extensions: [new PathStyleExtension({ dash: true })],
      pickable: true,
      visible: checked,
    }),

    new MVTLayer({
      id: "sDrain",
      data: `https://a.tiles.mapbox.com/v4/hazensawyer.6439un68/{z}/{x}/{y}.vector.pbf?access_token=pk.eyJ1IjoiaGF6ZW5zYXd5ZXIiLCJhIjoiY2xmNGQ3MDgyMTE3YjQzcnE1djRpOGVtNiJ9.U06GItbSVWFTsvfg9WwQWQ`,

      minZoom: 0,
      maxZoom: 23,
      getLineColor: [255, 127, 80, 255],
      opacity: 0.5,    
      getFillColor: [140, 170, 180],
      getLineWidth: 0.2,
      lineWidthMinPixels: 1,
      getDashArray: [10, 8],
      dashJustified: true,
      dashGapPickable: true,
      extensions: [new PathStyleExtension({ dash: true })],
      pickable: true,
      visible: checked,
    }),
  ];

  const handleDate = (e: ChangeEvent<HTMLInputElement>) => {
    setDate(e.target.value);
  };

  const handleTime = (e: ChangeEvent<HTMLInputElement>) => {
    setTime(e.target.value);
  };

  const handleTrack = (e: ChangeEvent<HTMLInputElement>) => {
    setTrack(parseInt(e.target.value));
  };

  const handleSelectChange = (event: React.ChangeEvent<HTMLSelectElement>) => {
    const value = event.target.value;
    //console.log(value);
    setType(value);
  }

  const handleDiameter = (e: ChangeEvent<HTMLInputElement>) => {
    setDiameter(parseInt(e.target.value));
  }

  const handleLength = (e: ChangeEvent<HTMLInputElement>) => {
    setLength(parseInt(e.target.value));
  }

  const handleUserName = async () => {
    const name = await checkLoginAndGetName();
    //console.log((name));
    if (name) {
      setUserName(name)
    }
  }

  const handleDescription = (e: ChangeEvent<HTMLInputElement>) => {
    setDescription(e.target.value);
  }

  useEffect(() => {

    client.models.Location.observeQuery().subscribe({
      next: (data) => setLocation([...data.items]),
    });
  }, []);

  useEffect(() => {
    handleUserName();
  }, []);



  function createLocation() {
    handleUserName();
    //console.log(typeof userName);
    //console.log("Username:", userName);
    const name = userName
    //console.log(name);
    client.models.Location.create({
      date: date,
      time: time,
      track: track,
      type: type,
      diameter: diameter,
      length: length,
      username: name,
      description: description,


      lat: lat,
      lng: lng,

    });
    setDate("");
    setTime("");
    setTrack(track);
    setType(type);
    setDiameter(diameter);
    setUserName("");
    setDescription("");
    setLat(0);
    setLng(0);
  }

  async function deleteLocation2(id: string, photourls: (string|null)[]) :
    Promise<{ 
      response: number 
      info: string
  }>{
    console.log('called delete location ')
    console.log("id=", id)
    console.log("photourl=", photourls )

    photourls.forEach( 
            async (aPath) => {
                if (aPath) 
                    try{ 
                       await remove({ path: aPath })
                    }catch(error) {
                        console.error('Error deleting photoes:', error);
                        return {response: 299, info:'failed'}
                    } 
            }
    )

    
    client.models.Location.delete({ id })

    return {response:200, info:'success'};
    /*
    const result = await deleteLocationPhotos(id)
    if (result.response == 200 ) {
      client.models.Location.delete({ id })
    }else {
      console.log(" error to delete photos ")
    }*/
  }

  async function deleteLocation(id: string) {
    const result = await deleteLocationPhotos(id)
    console.log( "result =", result.response)
    if (result.response == 200 ) {
      client.models.Location.delete({ id })
    }else {
      console.log(" error to delete photos ")
    }
  }

  function getTooltip(info: PickingInfo) {
    const d = info.object as DataT;
    if (d) {
      // console.log(info);
      if (info.layer?.id === "history") {
        return {
          html: `<u>History</u> <br>
          <div>Date: ${d.properties.date}</div>
          <div>Time: ${d.properties.time}</div>
           <div>track: ${d.properties.track}</div>
        <div>Type: ${d.properties.type}</div>`,
          style: {
            backgroundColor: "#AFE1AF",
            color: "#000",
            padding: "5px",
            borderRadius: "3px",
            boxShadow: "0 2px 4px rgba(0, 0, 0, 0.2)",
          },
        };
      } else if (info.layer?.id === "mh") {
        return {
          html: `<u>Manhole</u> <br>`,
          style: {
            backgroundColor: "#AFE1AF",
            color: "#000",
            padding: "5px",
            borderRadius: "3px",
            boxShadow: "0 2px 4px rgba(0, 0, 0, 0.2)",
          },
        };
      } else if (info.layer?.id === "gravity-public-pipe") {
        return {
          html: `<u>Gravity</u><br>`,
          style: {
            backgroundColor: "#AFE1AF",
            color: "#000",
            padding: "5px",
            borderRadius: "3px",
            boxShadow: "0 2px 4px rgba(0, 0, 0, 0.2)",
          },
        };
      } else if (info.layer?.id === "gravity-private-pipe") {
        return {
          html: `<u>Gravity</u><br>`,
          style: {
            backgroundColor: "#AFE1AF",
            color: "#000",
            padding: "5px",
            borderRadius: "3px",
            boxShadow: "0 2px 4px rgba(0, 0, 0, 0.2)",
          },
        };
      } else if (info.layer?.id === "fmpipe") {
        return {
          html: `<u>Force Main</u><br>`,
          style: {
            backgroundColor: "#AFE1AF",
            color: "#000",
            padding: "5px",
            borderRadius: "3px",
            boxShadow: "0 2px 4px rgba(0, 0, 0, 0.2)",
          },
        };
      } else {
      }
    }
    return null;
  }

  function onClick(info: PickingInfo) {
    //const safeInfo=info|| [];
    const f = info.coordinate as [number, number];
    setLng(Number(f[0].toFixed(25)));
    setLat(Number(f[1].toFixed(25)));

    const d = info.object as DataT;
    if (d) {
      setClickInfo(d);
      //console.log(clickInfo);
      console.log(showPopup);
      return {
        html: `<div>${d.properties.date}</div></br>
          <div>${d.properties.time}</div></br>
         <div>${d.properties.type}</div></br>`,
        style: {
          backgroundColor: "#AFE1AF",
          color: "#000",
          padding: "5px",
          borderRadius: "3px",
          boxShadow: "0 2px 4px rgba(0, 0, 0, 0.2)",
        },
      };
    }

    return null;

  }

   async function handleSubmit(event: SyntheticEvent, id: string) {
    event.preventDefault();
    //console.log(id);
    //console.log(userName);

    if (userName) {
      let placePhotosUrls: string[] = [];
      console.log("before submit, photoes size ", placePhotos.length);
      const uploadResult = await uploadPhotos(placePhotos, id)   //Hong
      placePhotosUrls = uploadResult.urls;

      const currentLoc= await client.models.Location.get( {
         id: id
      })

      let revised:string[] = []
      if ( currentLoc.data?.photos) {
         currentLoc.data.photos.forEach( 
           (d)=>{
              d? revised.push(d):null
           }
         )
      }

      await client.models.Location.update({
        id: id,
        photos: [...placePhotosUrls,...revised]

      })


      clearFields();
    }
  }

  function clearFields() {
    //setuserName('');
    setPlacePhotos([]);
  }

  async function uploadPhotos(files: File[], id: string): Promise<{
    urls: string[]

  }> {
    const urls: string[] = [];
    console.log('start to upload photos')
    console.log('# of files', files.length)

    for (const file of files) {
      console.log(`uploading file ${file.name}`)
      const result = await uploadData({
        data: file,
        path: `originals/${id}/${file.name}`
      }).result
      urls.push(result.path);
      console.log('url is ', urls);

    }
    return {
      urls,

    };
  }

  //Hong's addition
  function previewPhotos(event: CustomEvent) {
        
        if (event.target.files) {
            const eventPhotos = Array.from(event.target.files);
            //const newFiles: File[] = [...new Set([...eventPhotos, ...placePhotos])]
            //console.log("newFiles =", newFiles)
            //setPlacePhotos(newFiles);
            setPlacePhotos(eventPhotos)
        }
  }

  function renderPhotos() {

    const rows: any[] = []

        if (location ) {

            location.forEach ( (loc, index) => {
              if (loc.photos) {

                rows.push(
                  <h4>Date: {loc.date}  &nbsp; &nbsp;&nbsp; Description: {loc.description} 
                  &nbsp; &nbsp; &nbsp;</h4>)
                loc.photos.forEach((photo, idx ) => {
                  if (photo) {
                    rows.push(<StorageImage path={photo} 
                      alt={photo} key={index*1000+idx} height={300} 
                      style={{marginLeft: '10px'}}/>)
                  }
                })
                 
              }
            })
        }
        return rows;
    }

   async function deleteLocationPhotos( locId: string): Promise<{
    response: number 
    info: string
    }> {
         console.log( "Loc Id = " + locId)
         if (location) {
            try{ 
              
                await remove({ path: `originals/${locId}` })
            }catch(error) {
                console.error('Error deleting photoes:', error);
                return {response: 299, info:'failed'}
            } 
          }
          return {response:200, info:'success'};
    }

  //end Hong's addition

  function useExpenseAggregates() {
    const [items, setItems] = useState<Array<Schema["Location"]["type"]>>([]);

    useEffect(() => {
      // Realtime query (updates when data changes)
      const sub = client.models.Location.observeQuery({
        // optional: add filter to limit what you pull down
        // filter: { createdAt: { ge: "2025-12-01T00:00:00.000Z" } },
      }).subscribe({
        next: ({ items }) => setItems(items),
        error: (err) => console.error(err),
      });

      return () => sub.unsubscribe();
    }, []);

    const aggregates = useMemo(() => {
      const byCategory: ByCategory = {};
      let totalSum = 0;

      for (const e of items) {
        const cat = e.track ?? 0;
        const amt = Number(e.length ?? 0);

        totalSum += amt;

        if (!byCategory[cat]) byCategory[cat] = { count: 0, sum: 0 };
        byCategory[cat].count += 1;
        byCategory[cat].sum += amt;
      }

      return { totalSum, byCategory, totalCount: items.length };
    }, [items]);

    return aggregates;
  }



  return (
    <main>
      <h1>Washington Park Project</h1>
      <Divider orientation="horizontal" />
      <br />
      <Flex>
        <Button onClick={signOut} width={120}>
          Sign out
        </Button>
        <Button onClick={createLocation} backgroundColor={"azure"} color={"red"}>
          + new
        </Button>
      </Flex>
      <br />
      <Flex direction="row">

        <input
          type="date"
          value={date}
          placeholder="date"
          onChange={handleDate}
        //width="150%"
        />
        <input
          type="time"
          value={time}
          placeholder="time"
          onChange={handleTime}
        //width="150%"
        />
        <input
          type="number"
          value={track}
          placeholder="track"
          onChange={handleTrack}
        //width="150%"
        />
        <SelectField
          label="Select an option"
          labelHidden={true}
          value={type}
          onChange={handleSelectChange}
        //width="100%"
        >
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </SelectField>


        <input
          type="number"
          value={diameter}
          placeholder="diameter (in)"
          onChange={handleDiameter}
        //width="150%"
        />
        <input
          type="number"
          value={length}
          placeholder="length (ft)"
          onChange={handleLength}
        //width="150%"
        />
        <input
          type="text"
          value={description}
          placeholder="description"
          onChange={handleDescription}
        //width="150%"
        />
        <Input type="number" value={Number(lat.toFixed(10))} />
        <Input type="number" value={Number(lng.toFixed(10))} />
      </Flex>
      <Divider orientation="horizontal" />
      <br />
      <Tabs
        value={tab}
        onValueChange={(tab) => setTab(tab)}
        items={[
          {
            label: "History Map",
            value: "1",
            content: (<>
              <Map
                initialViewState={{
                  longitude: -80.20321,
                  latitude: 26.00068,
                  zoom: 16,
                }}
                mapLib={maplibregl}
                mapStyle={MAP_STYLE} // Use any MapLibre-compatible style
                style={{
                  width: "100%",
                  height: "800px",
                  borderColor: "#000000",
                }}
              >
                <DeckGLOverlay
                  layers={layers}
                  getTooltip={getTooltip}
                  onClick={onClick}

                />
                <Marker latitude={Number(lat.toFixed(10))} longitude={Number(lng.toFixed(10))} />
                {clickInfo && (
                  <Popup
                    key={`${clickInfo.geometry.coordinates[0]}-${clickInfo.geometry.coordinates[1]}`}
                    latitude={clickInfo.geometry.coordinates[1]}
                    longitude={clickInfo.geometry.coordinates[0]}
                    anchor="bottom"
                    onClose={() => setShowPopup(false)}
                  >
                    {clickInfo.properties.date} <br />
                    {clickInfo.properties.track} <br />
                    {clickInfo.properties.type} <br />
                    <Button
                      onClick={() => {
                        console.log("clickinfo =" + clickInfo);
                        deleteLocation(clickInfo.properties.id);
                        setShowPopup(false);
                      }}
                    >
                      Delete{" "}
                    </Button>
                    <br />
                    <br />


                    <label>Place photos:</label><br />
                    <input type="file" multiple 
                     onChange={(e) => previewPhotos(e)}
                     placeholder="new picture"
                    /><br />
                    
                    <Button
                      onClick={(e) => {
                        console.log(clickInfo.properties);
                        handleSubmit(e, clickInfo.properties.id);
                        setShowPopup(false);
                      }}
                    >
                      Upload
                    </Button>
                  </Popup>
                )}
                <NavigationControl position="top-right" />
                <GeolocateControl position="top-right" positionOptions={{ enableHighAccuracy: true }}
                  trackUserLocation={true}
                  // Draw an arrow next to the location dot to indicate which direction the device is heading.
                  showUserHeading={true} />
                {/* {showPopup && (
                    <Popup
                      longitude={-80.22}
                      latitude={26.0}
                      anchor="bottom"
                      onClose={() => setShowPopup(false)}
                    >
                      You are here
                    </Popup>
                  )} */}
                <CheckboxField
                  name="subscribe-controlled"
                  value="yes"
                  checked={checked}
                  onChange={(e) => setChecked(e.target.checked)}
                  //onChange={handleRoundChange}
                  label="Base Layers"
                />
              </Map>
            </>)
          },
          {
            label: "History Data",
            value: "2",
            content: (<>
              <ScrollView
                as="div"
                ariaLabel="View example"
                backgroundColor="var(--amplify-colors-white)"
                borderRadius="6px"
                //border="1px solid var(--amplify-colors-black)"
                // boxShadow="3px 3px 5px 6px var(--amplify-colors-neutral-60)"
                color="var(--amplify-colors-blue-60)"
                // height="45rem"
                // maxWidth="100%"
                padding="1rem"
              // width="100%"
              // width="1000px"
              // height={"2400px"}
              // maxHeight={"2400px"}
              // maxWidth="1000px"

              >
                <ThemeProvider theme={theme} colorMode="light">
                  <Table caption="" highlightOnHover={false} variation="striped"
                    style={{
                      //tableLayout: 'fixed',
                      width: '100%',
                      fontFamily: 'Arial, sans-serif',
                    }}>
                    <TableHead>
                      <TableRow>
                        <TableCell as="th" /* style={{ width: '15%' }} */>Date</TableCell>
                        <TableCell as="th" /* style={{ width: '15%' }} */>Time</TableCell>
                        <TableCell as="th" /* style={{ width: '10%' }} */>Track</TableCell>
                        <TableCell as="th" /* style={{ width: '15%' }} */>Type</TableCell>
                        <TableCell as="th" /* style={{ width: '15%' }} */>User</TableCell>
                        <TableCell as="th" /* style={{ width: '15%' }} */>Diameter</TableCell>
                        <TableCell as="th" /* style={{ width: '15%' }} */>Length</TableCell>
                        <TableCell as="th" /* style={{ width: '15%' }} */>Images</TableCell>
                        <TableCell as="th" /* style={{ width: '15%' }} */>Latitude</TableCell>
                        <TableCell as="th" /* style={{ width: '15%' }} */>Longitude</TableCell>
                      </TableRow>
                      </TableHead>
                      <TableBody>
                        {location.map((location) => (
                          <TableRow
                            onDoubleClick={(e) =>{
                                console.log( "location photos url =", location.photos)
                                console.log(e)
                                if ( location.photos)
                                  deleteLocation2(location.id, location.photos)
                                else 
                                  deleteLocation(location.id)
                            } 


                            }
                            key={location.id}
                          >
                            <TableCell /* width="15%" */>{location.date}</TableCell>
                            <TableCell /* width="15%" */>{location.time}</TableCell>
                            <TableCell /* width="10%" */>{location.track}</TableCell>
                            <TableCell /* width="15%" */>{location.type}</TableCell>
                            <TableCell /* width="15%" */>{location.username}</TableCell>
                            <TableCell /* width="15%" */>{location.diameter}</TableCell>
                            <TableCell /* width="15%" */>{location.length}</TableCell>
                            <TableCell /* width="15%" */>{location.photos? location.photos.length:0}</TableCell>
                            <TableCell /* width="15%" */>{location.lat}</TableCell>
                            <TableCell /* width="15%" */>{location.lng}</TableCell>  
                          </TableRow>
                        ))}
                      </TableBody>
                    
                  </Table>
                </ThemeProvider>
              </ScrollView>
            </>)
          },
          {
            label: "Statistics",
            value: "3",
            content: (<>
              <div>
                <h2>Total Length (ft): {totalSum.toFixed(0)} ({totalCount} items)</h2>

                <ul>
                  {Object.entries(byCategory).map(([cat, v]) => (
                    <li key={cat}>
                      {cat}: {v.sum.toFixed(0)} feet ({v.count} counts)
                    </li>
                  ))}
                </ul>
              </div>
            </>)
          },
          {
            label: "Photos",
            value: "4",
            content: (<>
              <h3>Photos and Comments</h3>
              {renderPhotos()}
            </>)
          },
        ]}
      />

    </main>
  );
}

export default App;
