import type { LicenseReading } from './license-assessment';

type Source = HTMLImageElement | HTMLVideoElement;
const cardRatio = 85.6 / 53.98;

export function photoCanvas(source: Source, crop = false, maximum = 1400) {
  const width = 'videoWidth' in source ? source.videoWidth : source.naturalWidth;
  const height = 'videoHeight' in source ? source.videoHeight : source.naturalHeight;
  if (!width || !height) throw new Error('Espera a que cargue la imagen.');
  const cropWidth = crop ? Math.min(width, height * cardRatio) * 0.92 : width;
  const cropHeight = crop ? cropWidth / cardRatio : height;
  const scale = Math.min(1, maximum / Math.max(cropWidth, cropHeight));
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(cropWidth * scale);
  canvas.height = Math.round(cropHeight * scale);
  const ctx = canvas.getContext('2d')!;
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(source, (width-cropWidth)/2, (height-cropHeight)/2, cropWidth, cropHeight, 0, 0, canvas.width, canvas.height);
  return canvas;
}

export async function canvasPhoto(canvas: HTMLCanvasElement, name: string) {
  const blob = await new Promise<Blob | null>(resolve => canvas.toBlob(resolve, 'image/jpeg', 0.82));
  if (!blob) throw new Error('No se pudo preparar la foto. Intenta nuevamente.');
  return new File([blob], name, {type:'image/jpeg'});
}

export async function imageCanvas(file: File, maximum = 1400) {
  if (file.size > 20_000_000) throw new Error('Selecciona una imagen de hasta 20 MB.');
  const url = URL.createObjectURL(file);
  try {
    const image = new Image();
    image.src = url;
    await image.decode();
    return photoCanvas(image, false, maximum);
  } catch { throw new Error('Selecciona una imagen JPG, PNG o WebP válida.'); }
  finally { URL.revokeObjectURL(url); }
}

export function quality(canvas: HTMLCanvasElement): LicenseReading['calidad'] {
  if (canvas.width < 280 || canvas.height < 170) return 'fuera_de_marco';
  const sample = document.createElement('canvas'); sample.width = 200; sample.height = 120;
  const ctx = sample.getContext('2d', {willReadFrequently:true})!;
  ctx.drawImage(canvas,0,0,200,120);
  const pixels = ctx.getImageData(0,0,200,120).data, values = new Float32Array(pixels.length/4);
  let sum = 0, squared = 0, light = 0, edges = 0;
  for (let i=0;i<values.length;i++) { values[i]=pixels[4*i]*0.299+pixels[4*i+1]*0.587+pixels[4*i+2]*0.114; sum+=values[i]; squared+=values[i]**2; if(values[i]>50) light++; }
  if (light/values.length < 0.05) return 'oscura';
  const contrast=squared/values.length-(sum/values.length)**2;
  for(let y=1;y<119;y++) for(let x=1;x<199;x++){const i=y*200+x;edges+=(4*values[i]-values[i-1]-values[i+1]-values[i-200]-values[i+200])**2;}
  if(contrast<9) return 'fuera_de_marco';
  if(edges/(118*198)<12) return 'borrosa';
}

type TextDetector = new () => { detect(image: HTMLCanvasElement): Promise<Array<{rawValue:string}>> };
export async function readLicense(front: File, back: File): Promise<LicenseReading> {
  const [first, second] = await Promise.all([imageCanvas(front),imageCanvas(back)]);
  const issue = quality(first) || quality(second);
  if (issue) return {calidad:issue};
  const Detector = (window as Window & {TextDetector?:TextDetector}).TextDetector;
  if (!Detector) return {};
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const detector = new Detector();
    const text = await Promise.race([
      Promise.all([detector.detect(first),detector.detect(second)]).then(results=>results.flat().map(r=>r.rawValue).join('\n')),
      new Promise<string>(resolve=>{timer=setTimeout(()=>resolve(''),6000);}),
    ]);
    const holder = text.match(/(?:NOMBRE(?:S)?(?: DEL TITULAR)?)[ \t]*[:\n][ \t]*([\p{L}][\p{L} .'-]{8,150})/iu)?.[1]?.trim();
    const expiry = text.match(/(?:VENCIMIENTO|EXPIRACI[ÓO]N)[ \t]*[:\n]?\s*(?:\d{1,2}[/.-])?(0?[1-9]|1[0-2])[/.-](20\d{2})\b/iu);
    return {nombre:holder,vencimiento:expiry ? `${expiry[2]}-${expiry[1].padStart(2,'0')}` : undefined};
  } catch { return {}; }
  finally { clearTimeout(timer); }
}
