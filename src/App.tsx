import type { ChangeEvent, SyntheticEvent } from "react";
import { useEffect, useState, useCallback, useMemo } from "react";
import type { Schema } from "../amplify/data/resource";
import { checkLoginAndGetName } from "./utils/AuthUtils";
import { useAuthenticator } from '@aws-amplify/ui-react';
import { generateClient } from "aws-amplify/data";
import "@aws-amplify/ui-react/styles.css";
import { uploadData, remove } from "aws-amplify/storage";
import { StorageImage } from '@aws-amplify/ui-react-storage';

import type { MapMouseEvent } from "mapbox-gl";


import 'mapbox-gl/dist/mapbox-gl.css';
//import { useGeoJSON } from './useGeoJSON';

import type { WaterFeatureProperties } from './types';
import './MapView.css';

//import { MapboxOverlay, MapboxOverlayProps } from "@deck.gl/mapbox/typed";
//import { PickingInfo } from "@deck.gl/core/typed";

import "maplibre-gl/dist/maplibre-gl.css";

import {
  Map,
  Source,
  Layer,
  //useControl,
  //Popup,
  Marker,
  NavigationControl,
  GeolocateControl,
  ScaleControl,
  Popup
} from "react-map-gl";



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
  Radio,
  RadioGroupField,
  //CheckboxField,
  // TextField,
} from "@aws-amplify/ui-react";


//import { IconLayer } from "@deck.gl/layers/typed";


//import type { WaterFeatureProperties } from './types';
import './FeaturePopup.css';

const MAPBOX_TOKEN = "pk.eyJ1IjoiaGF6ZW5zYXd5ZXIiLCJhIjoiY2xmMnY0NzE1MGMzMjNycGp6bDQwcWZsNyJ9.1JJeWIQgrykU5b3oqSr1sQ";
const client = generateClient<Schema>();


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

// type DataT = {
//   type: "Feature";
//   id: number;
//   geometry: {
//     type: "Point";
//     coordinates: [number, number, number];
//   };
//   properties: {
//     track: number;
//     type: string;
//     status: string;
//     date: string;
//     time: string;
//     id: string;
//   };
// };

type SelectOption = {
  value: string;
  label: string;
};



// Hong's addition
export type CustomEvent = {
  target: HTMLInputElement
}
// Hong's addition end

//const MAP_STYLE = "mapbox://styles/mapbox/streets-v12";
// "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json";


function PhotoImg({ path, height }: { path: string; height: number }) {
  return (
    <StorageImage
      path={path}
      alt="photo"
      height={height}
      style={{ marginLeft: '10px', marginBottom: '8px' }}
      onGetUrlError={(err: Error) => console.error(`StorageImage failed for "${path}":`, err)}
    />
  );
}

interface PopupInfo {
  longitude: number;
  latitude: number;
  properties: WaterFeatureProperties;
}


function App() {

  const { signOut } = useAuthenticator();
  //const client = generateClient<Schema>();
  const [location, setLocation] = useState<Array<Schema["Location"]["type"]>>([]);

  // Build a GeoJSON FeatureCollection directly from Amplify location state.
  // This replaces the external API URL (AIR_PORTS) which was returning
  // malformed JSON with invalid control characters, causing no points to render.
  const locationGeoJSON = useMemo(() => ({
    type: 'FeatureCollection' as const,
    features: location
      .filter(loc => loc.lat != null && loc.lng != null)
      .map(loc => ({
        type: 'Feature' as const,
        geometry: { type: 'Point' as const, coordinates: [loc.lng!, loc.lat!] },
        properties: {
          id:          loc.id,
          date:        loc.date ?? '',
          time:        loc.time ?? '',
          track:       loc.track ?? null,
          type:        loc.type ?? '',
          diameter:    loc.diameter ?? null,
          length:      loc.length ?? null,
          description: loc.description ?? '',
          joint:       loc.joint ?? null,
        },
      })),
  }), [location]);

  const [jointMap, setJointMap] = useState<Record<string, boolean | null>>({});
  type PhotoRecord = { id: string; date: string | null; description: string | null; photos: (string | null)[] | null };
  const [photosData, setPhotosData] = useState<PhotoRecord[]>([]);
  const [date, setDate] = useState("");
  const [time, setTime] = useState("");
  //const [report, setReport] = useState("");
  const [track, setTrack] = useState<number>(0);
  const [type, setType] = useState<string>("water");
  const [diameter, setDiameter] = useState<number>(0);
  const [length, setLength] = useState<number>(0);
  const [userName, setUserName] = useState<string>();
  const [description, setDescription] = useState<string>("");
  const [joint, setJoint] = useState<boolean>(true);
  const [lat, setLat] = useState(0);
  const [lng, setLng] = useState(0);
  const [placePhotos, setPlacePhotos] = useState<File[]>([]);

  const [tab, setTab] = useState("1");
  const [basemap, setBasemap] = useState("mapbox://styles/mapbox/streets-v12");
  const [calResult, setCalResult] = useState<number | null>(null);
  const [unitCosts, setUnitCosts] = useState<{ diameter: number; price: number }[]>([]);

  //const [clickInfo, setClickInfo] = useState<DataT>();
  //const [showPopup, setShowPopup] = useState<boolean>(true);


  //const { data } = useGeoJSON();
  const [popupInfo, setPopupInfo] = useState<PopupInfo | null>(null);
  const [cursor, setCursor] = useState<string>('grab');
  const [editTrack, setEditTrack] = useState<string>('');
  const [editDescription, setEditDescription] = useState<string>('');
  const [editDiameter, setEditDiameter] = useState<string>('');
  const [editType, setEditType] = useState<string>('water');
  const [editJoint, setEditJoint] = useState<boolean>(true);
  const [editDate, setEditDate] = useState<string>('');



  const options: SelectOption[] = [
    { value: 'water', label: 'Water' },
    { value: 'wastewater', label: 'Wastewater' },
    { value: 'stormwater', label: 'Stormwater' },
    { value: 'pavement', label: 'Pavement' }
  ];

  //console.log(AIR_PORTS);


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
    // Exclude 'comments' (a.ref custom type) from the selection set.
    // When comments is included, observeQuery's internal findIndexByFields
    // crashes with "Cannot read properties of null (reading 'id')" whenever
    // a record is updated and comments is null.
    const sub = client.models.Location.observeQuery({
      selectionSet: [
        'id', 'date', 'time', 'track', 'type', 'diameter',
        'length', 'lat', 'lng', 'username', 'description',
        'photos', 'joint', 'createdAt', 'updatedAt',
      ] as const,
    }).subscribe({
      next: (data) => setLocation([...data.items]),
      error: (err) => console.error('observeQuery error:', err),
    });
    return () => sub.unsubscribe();
  }, []);

  // Build jointMap directly from Amplify location state (no external fetch needed).
  useEffect(() => {
    const map: Record<string, boolean | null> = {};
    location.forEach(loc => { map[loc.id] = loc.joint ?? null; });
    setJointMap(map);
  }, [location]);

  useEffect(() => {
    const fetchAllPhotos = async () => {
      try {
        let all: PhotoRecord[] = [];
        let nextToken: string | null | undefined = undefined;
        do {
          const { data, nextToken: token }: { data: any[]; nextToken?: string | null } =
            await client.models.Location.list({
              limit: 1000,
              nextToken,
              selectionSet: ['id', 'date', 'description', 'photos'] as const,
            });
          all = all.concat(data.map(d => ({
            id: d.id,
            date: d.date ?? null,
            description: d.description ?? null,
            photos: d.photos ?? null,
          })));
          nextToken = token;
        } while (nextToken);
        setPhotosData(all);
      } catch (err) {
        console.error('Failed to fetch photos:', err);
      }
    };
    fetchAllPhotos();
  }, [location]);

  useEffect(() => {
    handleUserName();
  }, []);

  useEffect(() => {
    fetch("https://50fb42daa5.execute-api.us-east-1.amazonaws.com/test/getData")
      .then(res => res.json())
      .then(data => setUnitCosts(data))
      .catch(err => console.error("Failed to fetch unit costs:", err));
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
      length: calResult !== null ? calResult : length,
      username: name,
      description: description,


      lat: lat,
      lng: lng,
      joint: joint,

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

  async function deleteLocation2(id: string, photourls: (string | null)[]):
    Promise<{
      response: number
      info: string
    }> {
    console.log('called delete location ')
    console.log("id=", id)
    console.log("photourl=", photourls)

    photourls.forEach(
      async (aPath) => {
        if (aPath)
          try {
            await remove({ path: aPath })
          } catch (error) {
            console.error('Error deleting photoes:', error);
            return { response: 299, info: 'failed' }
          }
      }
    )


    client.models.Location.delete({ id })

    return { response: 200, info: 'success' };
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
    console.log("result =", result.response)
    if (result.response == 200) {
      client.models.Location.delete({ id })
    } else {
      console.log(" error to delete photos ")
    }
  }





  async function handleSubmit(event: SyntheticEvent, id: string) {
    event.preventDefault();

    let placePhotosUrls: string[] = [];
    console.log("before submit, photoes size ", placePhotos.length);
    const uploadResult = await uploadPhotos(placePhotos, id);
    placePhotosUrls = uploadResult.urls;

    const currentLoc = await client.models.Location.get({ id });

    let revised: string[] = [];
    if (currentLoc.data?.photos) {
      currentLoc.data.photos.forEach(d => { if (d) revised.push(d); });
    }

    await client.models.Location.update({
      id: id,
      photos: [...placePhotosUrls, ...revised]
    });

    clearFields();
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

  async function deleteLocationPhotos(locId: string): Promise<{
    response: number
    info: string
  }> {
    console.log("Loc Id = " + locId)
    if (location) {
      try {

        await remove({ path: `originals/${locId}` })
      } catch (error) {
        console.error('Error deleting photoes:', error);
        return { response: 299, info: 'failed' }
      }
    }
    return { response: 200, info: 'success' };
  }

  //end Hong's addition

  async function handleUpdatePopup(id: string) {
    // Use raw GraphQL to bypass the Amplify Gen 2 client-side field-validation
    // bug triggered by the `comments: a.ref('Comment').array()` custom type.
    const mutation = /* GraphQL */ `
      mutation UpdateLocation($input: UpdateLocationInput!) {
        updateLocation(input: $input) {
          id
          date
          track
          type
          diameter
          description
          joint
        }
      }
    `;
    try {
      const input: Record<string, unknown> = { id };
      input.date        = editDate;
      input.type        = editType;
      input.description = editDescription;
      input.joint       = editJoint;
      const parsedTrack    = parseInt(editTrack);
      const parsedDiameter = parseFloat(editDiameter);
      if (editTrack    !== '' && !isNaN(parsedTrack))    input.track    = parsedTrack;
      if (editDiameter !== '' && !isNaN(parsedDiameter)) input.diameter = parsedDiameter;

      console.log('Updating via GraphQL:', input);
      const result = await (client as any).graphql({ query: mutation, variables: { input } });
      console.log('Update result:', result);

      // Manually patch local state so the UI reflects the change immediately,
      // independent of the observeQuery subscription which can crash on custom types.
      const { data: fresh } = await client.models.Location.get({ id });
      if (fresh) {
        setLocation(prev => prev.map(loc => loc.id === id ? fresh : loc));
      }
      setPopupInfo(null);
    } catch (err) {
      console.error('Update exception:', err);
      alert('Save failed: ' + String(err));
    }
  }

  function haversineDistanceFt(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 20902464; // Earth radius in feet
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  function handleCal() {
    const sameTrack = location.filter(loc => loc.track === track);
    if (sameTrack.length === 0) {
      setCalResult(0);
      return;
    }

    // Find the point with the latest combined date+time on the same track
    let latest: Schema["Location"]["type"] | null = null;
    let latestDT = "";
    for (const loc of sameTrack) {
      const dt = (loc.date ?? "") + "T" + (loc.time ?? "");
      if (dt > latestDT) {
        latestDT = dt;
        latest = loc;
      }
    }

    if (!latest || latest.lat == null || latest.lng == null) {
      setLength(0);
      setCalResult(0);
      return;
    }

    setCalResult(haversineDistanceFt(lat, lng, latest.lat, latest.lng));
  }

  const onClick = useCallback((e: MapMouseEvent) => {
    const feature = e.features?.[0];

    //console.log("clicked feature =", feature);
    if (!feature || feature.geometry.type !== 'Point') {
      //console.log(e);
      setLat(e.lngLat.lat);
      setLng(e.lngLat.lng);
      setPopupInfo(null);
    }
    else {

      const [lng, lat] = feature.geometry.coordinates;
      const props = feature.properties as WaterFeatureProperties;
      const match = location.find(loc => loc.id === props.id);
      setPopupInfo({
        longitude: lng,
        latitude: lat,
        properties: { ...props, joint: match?.joint ?? null },
      });
      setEditTrack(props.track != null ? String(props.track) : '');
      setEditDescription(props.description ?? '');
      setEditDiameter(props.diameter != null ? String(props.diameter) : '');
      setEditType(props.type ?? 'water');
      setEditJoint(match?.joint !== false);
      setEditDate(match?.date ?? props.date ?? '');
    };
  }, [location]);

  const onMouseEnter = useCallback(() => setCursor('pointer'), []);
  const onMouseLeave = useCallback(() => setCursor('grab'), []);

  const change_basemap = (value: string) => {
    if (value === "light") {
      setBasemap("mapbox://styles/mapbox/light-v11")
    } else if (value === "street") {
      setBasemap("mapbox://styles/mapbox/streets-v12")
    } else if (value === "satellite") {
      setBasemap("mapbox://styles/hazensawyer/clf4dasal001301qvxatwv8md")
    }
  };

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
        <Button onClick={handleCal} backgroundColor={"lightyellow"} color={"darkblue"}>
          Cal
        </Button>
        {calResult !== null && (
          <span style={{ alignSelf: "center", fontWeight: "bold" }}>
            Distance: {calResult.toFixed(1)} ft
          </span>
        )}
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
  
        <Input
          type="text"
          value={description}
          placeholder="description"
          onChange={handleDescription}
          width="800px"
        />
        <label style={{ display: 'flex', alignItems: 'center', gap: '4px', whiteSpace: 'nowrap' }}>
          <input
            type="checkbox"
            checked={joint}
            onChange={e => setJoint(e.target.checked)}
          />
          Joint
        </label>
        {/* <Input type="number" value={Number(lat.toFixed(10))} />
        <Input type="number" value={Number(lng.toFixed(10))} /> */}
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
                mapboxAccessToken={MAPBOX_TOKEN}
                //mapLib={maplibregl}
                mapStyle={basemap} // Use any MapLibre-compatible style

                style={{
                  width: "100%",
                  height: "1000px",
                  borderColor: "#000000",
                }}
                interactiveLayerIds={['water-points']}
                onClick={onClick}
                onMouseEnter={onMouseEnter}
                onMouseLeave={onMouseLeave}
                cursor={cursor}
              >
                <Source id="water-data" type="geojson" data={locationGeoJSON}>

                  <Layer
                    id='water-points'
                    type='circle'
                    source='water-data'
                    paint={{
                      'circle-radius': [
                        'case',
                        ['all', ['any', ['==', ['get', 'type'], 'wastewater'], ['==', ['get', 'type'], 'stormwater']], ['==', ['get', 'joint'], false]],
                        5,
                        ['all', ['any', ['==', ['get', 'type'], 'wastewater'], ['==', ['get', 'type'], 'stormwater']], ['==', ['get', 'joint'], true]],
                        3.5,
                        3.5
                      ],
                      'circle-color': [
                        'match',
                        ['get', 'type'],
                        'water', '#2b6cb0', // Diameter of exactly 10 is red
                        "wastewater", '#2ea160', // Diameter of exactly 20 is green
                        "stormwater", '#eca4a4',
                        "pavement", '#a0a0a0',  '#2b6cb0'       // Fallback color for any other value
                      ]/* '#2b6cb0' */,
                      'circle-stroke-color': '#ffffff',
                      'circle-stroke-width': 2,
                      'circle-opacity': 0.9,
                    }}
                  />
                </Source>

                <Source id="wMain" type="vector" url="mapbox://hazensawyer.5764gcxp">
                  <Layer
                    id='water-lines'
                    type='line'
                    source='wMain'
                    source-layer="wMain-1r1fzu"
                    paint={{
                      'line-width': 1,
                      // Use a get expression (https://docs.mapbox.comhttps://docs.mapbox.com/style-spec/reference/expressions/#get)
                      // to set the line-color to a feature property value.
                      'line-color': "#2b6cb0",
                      'line-dasharray': [4, 2]
                    }}
                  />
                </Source>
                <Source id="sgravity" type="vector" url="mapbox://hazensawyer.54mpxvz3">
                  <Layer
                    id='gravity-lines'
                    type='line'
                    source='sgravity'
                    source-layer="sGravity-d079ci"
                    paint={{
                      'line-width': 1,
                      // Use a get expression (https://docs.mapbox.comhttps://docs.mapbox.com/style-spec/reference/expressions/#get)
                      // to set the line-color to a feature property value.
                      'line-color': "#2ea160",
                      'line-dasharray': [4, 2]
                    }}
                  />
                </Source>
                <Source id="sdrain" type="vector" url="mapbox://hazensawyer.6439un68">
                  <Layer
                    id='storm-lines'
                    type='line'
                    source='sdrain'
                    source-layer="sDrain-7lho1y"
                    paint={{
                      'line-width': 1,
                      // Use a get expression (https://docs.mapbox.comhttps://docs.mapbox.com/style-spec/reference/expressions/#get)
                      // to set the line-color to a feature property value.
                      'line-color': "#eca4a4",
                      'line-dasharray': [4, 2]
                    }}
                  />
                </Source>
                <Marker latitude={Number(lat)} longitude={Number(lng)} />
                {popupInfo && (
                  <>
                    <Popup
                      longitude={popupInfo.longitude}
                      latitude={popupInfo.latitude}
                      anchor="bottom"
                      offset={12}
                      onClose={() => setPopupInfo(null)}
                      closeOnClick={false}
                    >
                      <div className="popup">
                        <h3 className="popup-title">
                          <span className="popup-type-badge">{popupInfo.properties.type}</span>
                          Water Infrastructure
                        </h3>
                        <table className="popup-table">
                          <tbody>
                            <tr>
                              <td>Date</td>
                              <td>
                                <input
                                  aria-label="Date"
                                  type="date"
                                  value={editDate}
                                  onChange={e => setEditDate(e.target.value)}
                                  style={{ fontSize: '11px', padding: '2px 4px', width: '100%' }}
                                />
                              </td>
                            </tr>
                            <tr>
                              <td>Type</td>
                              <td>
                                <select
                                  aria-label="Type"
                                  value={editType}
                                  onChange={e => setEditType(e.target.value)}
                                  style={{ fontSize: '11px', padding: '2px 4px', width: '100%' }}
                                >
                                  <option value="water">water</option>
                                  <option value="wastewater">wastewater</option>
                                  <option value="stormwater">stormwater</option>
                                  <option value="pavement">pavement</option>
                                </select>
                              </td>
                            </tr>
                            <tr>
                              <td>Track</td>
                              <td>
                                <input
                                  aria-label="Track"
                                  type="number"
                                  value={editTrack}
                                  onChange={e => setEditTrack(e.target.value)}
                                  style={{ fontSize: '11px', padding: '2px 4px', width: '100%' }}
                                />
                              </td>
                            </tr>
                            <tr>
                              <td>Diameter</td>
                              <td>
                                <input
                                  aria-label="Diameter"
                                  type="number"
                                  value={editDiameter}
                                  onChange={e => setEditDiameter(e.target.value)}
                                  style={{ fontSize: '11px', padding: '2px 4px', width: '100%' }}
                                />
                              </td>
                            </tr>
                            <tr>
                              <td>Description</td>
                              <td>
                                <input
                                  aria-label="Description"
                                  type="text"
                                  value={editDescription}
                                  onChange={e => setEditDescription(e.target.value)}
                                  style={{ fontSize: '11px', padding: '2px 4px', width: '100%' }}
                                />
                              </td>
                            </tr>
                            <tr>
                              <td>Joint</td>
                              <td>
                                <input
                                  aria-label="Joint"
                                  type="checkbox"
                                  checked={editJoint}
                                  onChange={e => setEditJoint(e.target.checked)}
                                  style={{ cursor: 'pointer', width: '14px', height: '14px' }}
                                />
                                <span style={{ fontSize: '11px', marginLeft: '6px' }}>
                                  {editJoint ? 'true' : 'false'}
                                </span>
                              </td>
                            </tr>
                          </tbody>
                        </table>
                        <div style={{ display: 'flex', gap: '6px', marginTop: '6px' }}>
                        <button
                          onClick={(e) => { e.stopPropagation(); handleUpdatePopup(popupInfo.properties.id); }}
                          style={{
                            fontSize: '11px', padding: '2px 8px', cursor: 'pointer',
                            border: '1px solid #2b6cb0', borderRadius: '3px',
                            background: '#fff', color: '#2b6cb0',
                          }}
                        >
                          Save
                        </button>
                        <button
                          onClick={() => {
                            deleteLocation(popupInfo.properties.id);
                            setPopupInfo(null);
                          }}
                          style={{
                            fontSize: '11px', padding: '2px 8px', cursor: 'pointer',
                            border: '1px solid #c00', borderRadius: '3px',
                            background: '#fff', color: '#c00',
                          }}
                        >
                          Delete
                        </button>
                        </div>
                        <br /><br />
                        <label style={{ fontSize: '11px' }}>Place photos:</label><br />
                        <input type="file" multiple
                          onChange={(e) => previewPhotos(e)}
                          placeholder="new picture"
                          style={{ fontSize: '11px' }}
                        /><br /><br />
                        <button
                          onClick={(e) => {
                            console.log(popupInfo.properties);
                            handleSubmit(e, popupInfo.properties.id);
                            setPopupInfo(null);
                          }}
                          style={{
                            fontSize: '11px', padding: '2px 8px', cursor: 'pointer',
                            border: '1px solid #555', borderRadius: '3px',
                            background: '#fff', color: '#333',
                          }}
                        >
                          Upload
                        </button>
                        <br /><br />
                        <button
                          onClick={(e) => { e.stopPropagation(); handleUpdatePopup(popupInfo.properties.id); }}
                          style={{
                            fontSize: '12px', padding: '4px 16px', cursor: 'pointer',
                            border: '1px solid #2b6cb0', borderRadius: '4px',
                            background: '#2b6cb0', color: '#fff', fontWeight: 600,
                            width: '100%',
                          }}
                        >
                          Apply
                        </button>
                      </div>
                    </Popup>

                  </>

                )}
                <NavigationControl position="top-right" />
                <ScaleControl position="bottom-right" unit='imperial' maxWidth={500} />
                <GeolocateControl position="top-right" positionOptions={{ enableHighAccuracy: true }}
                  trackUserLocation={true}
                  // Draw an arrow next to the location dot to indicate which direction the device is heading.
                  showUserHeading={true} />
                <RadioGroupField legend="Row" name="row" direction="row" onChange={(e) => change_basemap(e.target.value)} defaultValue="street">
                  <Radio value="light" >Light</Radio>
                  <Radio value="street">Street</Radio>
                  <Radio value="satellite">Satellite</Radio>
                </RadioGroupField>
                <div style={{
                  position: 'absolute',
                  bottom: '40px',
                  left: '10px',
                  background: 'rgba(255,255,255,0.92)',
                  padding: '10px 14px',
                  borderRadius: '6px',
                  boxShadow: '0 1px 5px rgba(0,0,0,0.25)',
                  fontSize: '12px',
                  lineHeight: '1',
                  zIndex: 1,
                }}>
                  <div style={{ fontWeight: 700, marginBottom: '8px', fontSize: '12px' }}>Legend</div>
                  {([
                    { label: 'Water',       color: '#2b6cb0' },
                    { label: 'Wastewater',  color: '#2ea160' },
                    { label: 'Stormwater',  color: '#eca4a4' },
                    { label: 'Pavement',    color: '#a0a0a0' },
                  ] as { label: string; color: string }[]).map(({ label, color }) => (
                    <div key={label} style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                      <span style={{
                        width: '12px', height: '12px', borderRadius: '50%',
                        background: color, border: '2px solid #fff',
                        boxShadow: '0 0 0 1px rgba(0,0,0,0.2)',
                        flexShrink: 0,
                      }} />
                      {label}
                    </div>
                  ))}
                </div>
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
                color="var(--amplify-colors-blue-60)"
                padding="1rem"
                height="700px"
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
                        <TableCell as="th">Joint</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {[...location].sort((a, b) => {
                          const trackDiff = (a.track ?? 0) - (b.track ?? 0);
                          if (trackDiff !== 0) return trackDiff;
                          const dateA = `${a.date ?? ''}T${a.time ?? ''}`;
                          const dateB = `${b.date ?? ''}T${b.time ?? ''}`;
                          return dateB.localeCompare(dateA);
                        }).map((location) => (
                        <TableRow
                          onDoubleClick={(e) => {
                            console.log("location photos url =", location.photos)
                            console.log(e)
                            if (location.photos)
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
                          <TableCell /* width="15%" */>{location.length != null ? Math.round(Number(location.length)) : ''}</TableCell>
                          <TableCell /* width="15%" */>{location.photos ? location.photos.length : 0}</TableCell>
                          <TableCell /* width="15%" */>{location.lat != null ? Number(location.lat).toFixed(6) : ''}</TableCell>
                          <TableCell /* width="15%" */>{location.lng != null ? Number(location.lng).toFixed(6) : ''}</TableCell>
                          <TableCell>{jointMap[location.id] == null ? '' : jointMap[location.id] ? 'true' : 'false'}</TableCell>
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
            content: (() => {
              const buildTableRows = (type: string) => {
                const items = location.filter(loc => loc.type === type);
                const aggMap: Record<string, { track: number; diameter: number; totalLength: number }> = {};
                for (const item of items) {
                  const key = `${item.track}-${item.diameter}`;
                  if (!aggMap[key]) {
                    aggMap[key] = { track: item.track ?? 0, diameter: item.diameter ?? 0, totalLength: 0 };
                  }
                  aggMap[key].totalLength += Number(item.length ?? 0);
                }
                return Object.values(aggMap).sort((a, b) => (a.track - b.track) || (a.diameter - b.diameter));
              };

              const fmt = (n: number) => n.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });

              const computePipeTotal = (type: string) =>
                buildTableRows(type).reduce((sum, row) => {
                  const unitCost = unitCosts.find(u => u.diameter === row.diameter)?.price ?? 0;
                  return sum + row.totalLength * unitCost;
                }, 0);

              const computePavTotal = () => {
                const TRACK_WIDTH_FT = 16;
                const UNIT_COST_PER_SY = 10;
                const totalLength = location
                  .filter(loc => loc.type === "pavement")
                  .reduce((sum, item) => sum + Number(item.length ?? 0), 0);
                return (totalLength * TRACK_WIDTH_FT / 9) * UNIT_COST_PER_SY;
              };

              const MH_UNIT_COST = 1500;
              const mhCount = location.filter(loc => loc.type === "wastewater" && jointMap[loc.id] === false).length;
              const mhCost = mhCount * MH_UNIT_COST;
              const swMhCount = location.filter(loc => loc.type === "stormwater" && jointMap[loc.id] === false).length;
              const swMhCost = swMhCount * MH_UNIT_COST;

              const t1Cost = computePipeTotal("water");
              const t2Cost = computePipeTotal("wastewater") + mhCost;
              const t3Cost = computePipeTotal("stormwater") + swMhCost;
              const t4Cost = computePavTotal();

              const COL_WIDTHS = ['8%', '13%', '13%', '13%', '13%', '22%', '18%'];
              const tableStyle = { width: '100%', fontFamily: 'Arial, sans-serif', tableLayout: 'fixed' as const };
              const thStyle = (i: number) => ({ width: COL_WIDTHS[i] });

              type ExtraRow = { cells: (string | number)[]; cost: number };
              const renderTable = (label: string, type: string, extras: ExtraRow[] = []) => {
                const rows = buildTableRows(type);
                const pipeCost = rows.reduce((sum, row) => {
                  const unitCost = unitCosts.find(u => u.diameter === row.diameter)?.price ?? 0;
                  return sum + row.totalLength * unitCost;
                }, 0);
                const totalCost = pipeCost + extras.reduce((s, e) => s + e.cost, 0);
                return (
                  <>
                    <h3>{label}</h3>
                    <ThemeProvider theme={theme} colorMode="light">
                      <Table caption="" highlightOnHover={false} variation="striped" style={tableStyle}>
                        <TableHead>
                          <TableRow>
                            <TableCell as="th" style={thStyle(0)}>Track</TableCell>
                            <TableCell as="th" style={thStyle(1)}>Type</TableCell>
                            <TableCell as="th" style={thStyle(2)}>Diameter (in)</TableCell>
                            <TableCell as="th" style={thStyle(3)}>Length (ft)</TableCell>
                            <TableCell as="th" style={thStyle(4)}>Area (sq yd)</TableCell>
                            <TableCell as="th" style={thStyle(5)}>Unit Cost ($/ft)</TableCell>
                            <TableCell as="th" style={thStyle(6)}>Cost ($)</TableCell>
                          </TableRow>
                        </TableHead>
                        <TableBody>
                          {rows.map(row => {
                            const unitCost = unitCosts.find(u => u.diameter === row.diameter)?.price ?? 0;
                            return (
                              <TableRow key={`${row.track}-${row.diameter}`}>
                                <TableCell>{row.track}</TableCell>
                                <TableCell>{type}</TableCell>
                                <TableCell>{row.diameter}</TableCell>
                                <TableCell>{row.totalLength.toFixed(1)}</TableCell>
                                <TableCell>—</TableCell>
                                <TableCell>{fmt(unitCost)}</TableCell>
                                <TableCell>{fmt(row.totalLength * unitCost)}</TableCell>
                              </TableRow>
                            );
                          })}
                          {extras.map((extra, i) => (
                            <TableRow key={`extra-${i}`}>
                              {extra.cells.map((cell, j) => <TableCell key={j}>{cell}</TableCell>)}
                              <TableCell>{fmt(extra.cost)}</TableCell>
                            </TableRow>
                          ))}
                          <TableRow>
                            <TableCell colSpan={6} style={{ fontWeight: 'bold', textAlign: 'right' }}>Total</TableCell>
                            <TableCell style={{ fontWeight: 'bold' }}>{fmt(totalCost)}</TableCell>
                          </TableRow>
                        </TableBody>
                      </Table>
                    </ThemeProvider>
                  </>
                );
              };

              return (
                <ScrollView height="calc(100vh - 250px)" padding="1rem">
                  {renderTable("Table 1 - Water", "water")}
                  <br />
                  {renderTable("Table 2 - Wastewater", "wastewater", [
                    { cells: ['—', 'wastewater', 'MH', mhCount, '—', `$${MH_UNIT_COST.toLocaleString()}/ea`], cost: mhCost }
                  ])}
                  <br />
                  {renderTable("Table 3 - Stormwater", "stormwater", [
                    { cells: ['—', 'stormwater', 'MH', swMhCount, '—', `$${MH_UNIT_COST.toLocaleString()}/ea`], cost: swMhCost }
                  ])}
                  <br />
                  {(() => {
                    const pavementItems = location.filter(loc => loc.type === "pavement");
                    const trackMap: Record<string, { track: number; totalLength: number }> = {};
                    for (const item of pavementItems) {
                      const key = String(item.track ?? 0);
                      if (!trackMap[key]) {
                        trackMap[key] = { track: item.track ?? 0, totalLength: 0 };
                      }
                      trackMap[key].totalLength += Number(item.length ?? 0);
                    }
                    const pavRows = Object.values(trackMap).sort((a, b) => a.track - b.track);
                    const TRACK_WIDTH_FT = 16;
                    const UNIT_COST_PER_SY = 10;
                    const pavTotal = pavRows.reduce((sum, row) => {
                      const areaSY = (row.totalLength * TRACK_WIDTH_FT) / 9;
                      return sum + areaSY * UNIT_COST_PER_SY;
                    }, 0);
                    return (
                      <>
                        <h3>Table 4 - Pavement</h3>
                        <ThemeProvider theme={theme} colorMode="light">
                          <Table caption="" highlightOnHover={false} variation="striped" style={tableStyle}>
                            <TableHead>
                              <TableRow>
                                <TableCell as="th" style={thStyle(0)}>Track</TableCell>
                                <TableCell as="th" style={thStyle(1)}>Type</TableCell>
                                <TableCell as="th" style={thStyle(2)}>Diameter (in)</TableCell>
                                <TableCell as="th" style={thStyle(3)}>Length (ft)</TableCell>
                                <TableCell as="th" style={thStyle(4)}>Area (sq yd)</TableCell>
                                <TableCell as="th" style={thStyle(5)}>Unit Cost ($/sq yd)</TableCell>
                                <TableCell as="th" style={thStyle(6)}>Cost ($)</TableCell>
                              </TableRow>
                            </TableHead>
                            <TableBody>
                              {pavRows.map(row => {
                                const areaSY = (row.totalLength * TRACK_WIDTH_FT) / 9;
                                const cost = areaSY * UNIT_COST_PER_SY;
                                return (
                                  <TableRow key={row.track}>
                                    <TableCell>{row.track}</TableCell>
                                    <TableCell>pavement</TableCell>
                                    <TableCell>—</TableCell>
                                    <TableCell>{row.totalLength.toFixed(1)}</TableCell>
                                    <TableCell>{areaSY.toFixed(1)}</TableCell>
                                    <TableCell>{fmt(UNIT_COST_PER_SY)}</TableCell>
                                    <TableCell>{fmt(cost)}</TableCell>
                                  </TableRow>
                                );
                              })}
                              <TableRow>
                                <TableCell colSpan={6} style={{ fontWeight: 'bold', textAlign: 'right' }}>Total</TableCell>
                                <TableCell style={{ fontWeight: 'bold' }}>{fmt(pavTotal)}</TableCell>
                              </TableRow>
                            </TableBody>
                          </Table>
                        </ThemeProvider>
                      </>
                    );
                  })()}
                  <br />
                  {(() => {
                    const summary = [
                      { label: "Table 1 - Water",       cost: t1Cost },
                      { label: "Table 2 - Wastewater",  cost: t2Cost },
                      { label: "Table 3 - Stormwater",  cost: t3Cost },
                      { label: "Table 4 - Pavement",    cost: t4Cost },
                    ];
                    const grandTotal = summary.reduce((sum, r) => sum + r.cost, 0);
                    return (
                      <>
                        <h3>Table 5 - Summary</h3>
                        <ThemeProvider theme={theme} colorMode="light">
                          <Table caption="" highlightOnHover={false} variation="striped" style={tableStyle}>
                            <TableHead>
                              <TableRow>
                                <TableCell as="th" colSpan={6} style={thStyle(0)}>Category</TableCell>
                                <TableCell as="th" style={thStyle(6)}>Cost ($)</TableCell>
                              </TableRow>
                            </TableHead>
                            <TableBody>
                              {summary.map(row => (
                                <TableRow key={row.label}>
                                  <TableCell colSpan={6}>{row.label}</TableCell>
                                  <TableCell>{fmt(row.cost)}</TableCell>
                                </TableRow>
                              ))}
                              <TableRow>
                                <TableCell colSpan={6} style={{ fontWeight: 'bold' }}>Grand Total</TableCell>
                                <TableCell style={{ fontWeight: 'bold' }}>{fmt(grandTotal)}</TableCell>
                              </TableRow>
                            </TableBody>
                          </Table>
                        </ThemeProvider>
                      </>
                    );
                  })()}
                </ScrollView>
              );
            })()
          },
          {
            label: "Photos",
            value: "4",
            content: (() => {
              const photoRows: React.ReactNode[] = [];
              photosData
                .filter(loc => loc.photos && loc.photos.length > 0)
                .sort((a, b) => {
                  const da = a.date ?? '';
                  const db = b.date ?? '';
                  return db.localeCompare(da);
                })
                .forEach((loc, index) => {
                  photoRows.push(
                    <div key={`h-${index}`} style={{ marginTop: '16px', marginBottom: '4px' }}>
                      <strong>Date:</strong> {loc.date ?? '—'}&nbsp;&nbsp;&nbsp;
                      <strong>Description:</strong> {loc.description ?? '—'}
                    </div>
                  );
                  loc.photos!.forEach((photo, idx) => {
                    if (photo) {
                      photoRows.push(
                        <PhotoImg
                          key={`${index}-${idx}`}
                          path={photo}
                          height={300}
                        />
                      );
                    }
                  });
                });
              return (
                <ScrollView height="calc(100vh - 250px)" style={{ padding: '16px' }}>
                  {photoRows.length > 0 ? photoRows : <p>No photos uploaded yet.</p>}
                </ScrollView>
              );
            })()
          },
        ]}
      />

    </main>
  );
}

export default App;
