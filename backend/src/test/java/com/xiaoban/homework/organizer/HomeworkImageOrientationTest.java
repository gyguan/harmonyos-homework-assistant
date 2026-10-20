package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import com.xiaoban.homework.common.ApiExceptions;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.zip.CRC32;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;

class HomeworkImageOrientationTest {
  static byte[] tiff(int orientation, ByteOrder order) {
    var data = ByteBuffer.allocate(26).order(order);
    data.put(order == ByteOrder.LITTLE_ENDIAN ? (byte)'I' : (byte)'M'); data.put(data.get(0));
    data.putShort((short)42).putInt(8).putShort((short)1);
    data.putShort((short)0x0112).putShort((short)3).putInt(1).putShort((short)orientation).putShort((short)0).putInt(0);
    return data.array();
  }
  static byte[] pngWithExif(byte[] png, byte[] tiff) throws Exception {
    var output = new ByteArrayOutputStream();
    output.write(png,0,33); output.write(ByteBuffer.allocate(4).putInt(tiff.length).array());
    byte[] kind = {'e','X','I','f'}; output.write(kind); output.write(tiff);
    var crc = new CRC32(); crc.update(kind); crc.update(tiff);
    output.write(ByteBuffer.allocate(4).putInt((int)crc.getValue()).array()); output.write(png,33,png.length-33);
    return output.toByteArray();
  }
  static byte[] jpegWithExif(byte[] jpeg, byte[] tiff) throws Exception {
    var output = new ByteArrayOutputStream(); output.write(jpeg,0,2);
    output.write(new byte[]{(byte)255,(byte)0xe1});
    output.write(ByteBuffer.allocate(2).putShort((short)(tiff.length+8)).array());
    output.write(new byte[]{'E','x','i','f',0,0}); output.write(tiff); output.write(jpeg,2,jpeg.length-2);
    return output.toByteArray();
  }
  private BufferedImage sample() {
    var image = new BufferedImage(3,2,BufferedImage.TYPE_INT_ARGB);
    int[] colors = {0xff010203,0xff123456,0xffabcdef,0x00556677,0x80102030,0xfffefdfc};
    for(int i=0;i<6;i++) image.setRGB(i%3,i/3,colors[i]); return image;
  }
  static byte[] encoded(BufferedImage image, String format) throws Exception {
    var output = new ByteArrayOutputStream(); assertTrue(ImageIO.write(image,format,output)); return output.toByteArray();
  }
  private HomeworkImageInput.Prepared prepare(byte[] bytes, String type) {
    return HomeworkImageInput.prepare(new HomeworkOrganizerDtos.ImageRequest(Base64.getEncoder().encodeToString(bytes),type,"图片",null));
  }
  private BufferedImage decode(HomeworkImageInput.Prepared image) throws Exception {
    return ImageIO.read(new ByteArrayInputStream(Base64.getDecoder().decode(image.dataUrl().split(",",2)[1])));
  }
  @Test void allEightOrientationsPreserveEachPixelAndAlphaInBothByteOrders() throws Exception {
    String[] expected = {"ABCDEF","CBAFED","FEDCBA","DEFABC","ADBECF","DAEBFC","FCEBDA","CFBEAD"};
    var original=sample(); byte[] png=encoded(original,"PNG");
    for(var order: List.of(ByteOrder.LITTLE_ENDIAN,ByteOrder.BIG_ENDIAN)) for(int orientation=1;orientation<=8;orientation++) {
      var result=prepare(pngWithExif(png,tiff(orientation,order)),"image/png");
      var actual=decode(result);
      assertEquals(orientation>=5 ? 2 : 3,actual.getWidth()); assertEquals(orientation>=5 ? 3 : 2,actual.getHeight());
      for(int index=0;index<6;index++) {
        int source=expected[orientation-1].charAt(index)-'A';
        assertEquals(original.getRGB(source%3,source/3),actual.getRGB(index%actual.getWidth(),index/actual.getWidth()),"orientation="+orientation);
      }
      assertEquals(orientation,result.orientation()); assertEquals(3,result.width()); assertEquals(2,result.height());
      if(orientation!=1) assertEquals(1,HomeworkImageOrientation.read(Base64.getDecoder().decode(result.dataUrl().split(",",2)[1]),"image/png"));
    }
  }
  @Test void jpegIsNormalizedOnceWithoutAnotherLossyEncodingAndUprightBytesStayIntact() throws Exception {
    var rgb=new BufferedImage(3,2,BufferedImage.TYPE_INT_RGB);
    rgb.setRGB(0,0,0xff0000); rgb.setRGB(2,1,0x00ff00);
    byte[] jpeg=encoded(rgb,"JPEG"); var original=ImageIO.read(new ByteArrayInputStream(jpeg));
    var prepared=prepare(jpegWithExif(jpeg,tiff(6,ByteOrder.LITTLE_ENDIAN)),"image/jpeg");
    assertTrue(prepared.dataUrl().startsWith("data:image/png;base64,")); var upright=decode(prepared);
    for(int y=0;y<2;y++) for(int x=0;x<3;x++) assertEquals(original.getRGB(x,y),upright.getRGB(1-y,x));
    assertEquals("data:image/jpeg;base64,"+Base64.getEncoder().encodeToString(jpeg),prepare(jpeg,"image/jpeg").dataUrl());
    assertEquals(1,prepare(jpeg,"image/jpeg").orientation());
  }
  private void ignoredExifKeepsOriginalPixels(byte[] input, byte[] clean, String type) throws Exception {
    var result = prepare(input, type);
    assertEquals("IGNORED_INVALID", result.orientationStatus());
    assertEquals(1, result.orientation());
    assertArrayEquals(clean, Base64.getDecoder().decode(result.dataUrl().split(",",2)[1]));
    var expected = ImageIO.read(new ByteArrayInputStream(clean));
    var actual = decode(result);
    assertEquals(expected.getWidth(), actual.getWidth()); assertEquals(expected.getHeight(), actual.getHeight());
    for (int y=0; y<expected.getHeight(); y++) for (int x=0; x<expected.getWidth(); x++)
      assertEquals(expected.getRGB(x,y), actual.getRGB(x,y));
  }
  @Test void malformedOptionalPngExifIsStrippedWithoutBlockingOrReencodingPixels() throws Exception {
    byte[] png=encoded(sample(),"PNG");
    for(int value: new int[]{0,9,65535}) ignoredExifKeepsOriginalPixels(pngWithExif(png,tiff(value,ByteOrder.BIG_ENDIAN)),png,"image/png");
    for(int length=0;length<22;length++)
      ignoredExifKeepsOriginalPixels(pngWithExif(png,Arrays.copyOf(tiff(6,ByteOrder.BIG_ENDIAN),length)),png,"image/png");
    for(int field: new int[]{4,8,12,14}) {
      byte[] corrupt=tiff(6,ByteOrder.BIG_ENDIAN); corrupt[field]=(byte)255;
      ignoredExifKeepsOriginalPixels(pngWithExif(png,corrupt),png,"image/png");
    }
    byte[] twice=pngWithExif(pngWithExif(png,tiff(2,ByteOrder.BIG_ENDIAN)),tiff(6,ByteOrder.BIG_ENDIAN));
    ignoredExifKeepsOriginalPixels(twice,png,"image/png");
    byte[] crc=pngWithExif(png,tiff(6,ByteOrder.BIG_ENDIAN)); crc[33+8+26]^=1;
    ignoredExifKeepsOriginalPixels(crc,png,"image/png");
  }
  @Test void malformedJpegExifDoesNotRecompressPhotoOrRemoveOtherAppSegments() throws Exception {
    byte[] jpeg=encoded(new BufferedImage(3,2,BufferedImage.TYPE_INT_RGB),"JPEG");
    var xmp=new ByteArrayOutputStream(); xmp.write(jpeg,0,2);
    byte[] contents="http://ns.adobe.com/xap/1.0/\0metadata".getBytes(java.nio.charset.StandardCharsets.US_ASCII);
    xmp.write(new byte[]{(byte)255,(byte)0xe1}); xmp.write(ByteBuffer.allocate(2).putShort((short)(contents.length+2)).array());
    xmp.write(contents); xmp.write(jpeg,2,jpeg.length-2);
    byte[] original=xmp.toByteArray();
    for(byte[] metadata:List.of(new byte[0],Arrays.copyOf(tiff(6,ByteOrder.BIG_ENDIAN),16),tiff(0,ByteOrder.LITTLE_ENDIAN)))
      ignoredExifKeepsOriginalPixels(jpegWithExif(original,metadata),original,"image/jpeg");
    byte[] twice=jpegWithExif(jpegWithExif(original,tiff(6,ByteOrder.BIG_ENDIAN)),tiff(8,ByteOrder.BIG_ENDIAN));
    ignoredExifKeepsOriginalPixels(twice,original,"image/jpeg");
  }
  @Test void completeOrientationWithoutUnrelatedIfd1PointerStillRotatesCorrectly() throws Exception {
    byte[] png=encoded(sample(),"PNG");
    for(var order:List.of(ByteOrder.LITTLE_ENDIAN,ByteOrder.BIG_ENDIAN)) for(int length=22;length<26;length++) {
      var result=prepare(pngWithExif(png,Arrays.copyOf(tiff(6,order),length)),"image/png");
      assertEquals(6,result.orientation()); assertEquals("VALID",result.orientationStatus());
      assertEquals(2,result.outputWidth()); assertEquals(3,result.outputHeight());
    }
  }
  @Test void pngExifIdentifierAndTrailingExporterDataDoNotInvalidateAValidImage() throws Exception {
    byte[] png=encoded(sample(),"PNG");
    var prefixed=new ByteArrayOutputStream(); prefixed.write(new byte[]{'E','x','i','f',0,0}); prefixed.write(tiff(8,ByteOrder.BIG_ENDIAN));
    assertEquals(8,prepare(pngWithExif(png,prefixed.toByteArray()),"image/png").orientation());
    byte[] trailer=Arrays.copyOf(png,png.length+20); Arrays.fill(trailer,png.length,trailer.length,(byte)0xff);
    var result=prepare(trailer,"image/png");
    assertEquals("ABSENT",result.orientationStatus());
    assertArrayEquals(trailer,Base64.getDecoder().decode(result.dataUrl().split(",",2)[1]));
    assertThrows(ApiExceptions.BadRequest.class,()->prepare(Arrays.copyOf(png,40),"image/png"));
  }
  @Test void normalizedOutputBudgetIsHardAndDoesNotFallBackToJpegOrDownscale() {
    var random=new java.util.Random(591); var image=new BufferedImage(32,32,BufferedImage.TYPE_INT_ARGB);
    for(int y=0;y<32;y++)for(int x=0;x<32;x++)image.setRGB(x,y,random.nextInt());
    var error=assertThrows(ApiExceptions.BadRequest.class,()->HomeworkImageInput.encodePng(image,100));
    assertTrue(error.getMessage().contains("超过4MB"));
  }
  @Test void originalHashSurvivesNormalizationAndTelemetryContainsOnlyProcessingMetadata() throws Exception {
    byte[] png=encoded(sample(),"PNG"), first=pngWithExif(png,tiff(6,ByteOrder.BIG_ENDIAN)), second=pngWithExif(png,tiff(6,ByteOrder.LITTLE_ENDIAN));
    var one=prepare(first,"image/png"); var two=prepare(second,"image/png");
    assertEquals(one.dataUrl(),two.dataUrl()); assertNotEquals(one.originalHash(),two.originalHash());
    try(var trace=HomeworkOrganizerTelemetry.open("orientation-test","IMAGE")) {
      HomeworkOrganizerTelemetry.image(one); var data=trace.measurement();
      assertTrue(data.containsKey("imagePreparation")); assertFalse(data.toString().contains("base64"));
      assertFalse(data.toString().contains(one.originalHash()));
    }
  }
}
