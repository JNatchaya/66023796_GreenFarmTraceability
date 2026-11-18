# GreenFarm Traceability

เว็บ React + Vite + TypeScript สำหรับติดตามล็อตสินค้าจากสัญญาใน `contracts/GreenFarmTraceability.sol` ใช้ viem อ่านข้อมูลผ่าน Infura และให้ MetaMask ยืนยันธุรกรรมบน Sepolia

## รันในเครื่อง

ใช้ Node.js 22 แล้วรัน `npm ci` และ `npm run dev` หากยังไม่ได้ตั้งค่า ระบบจะแสดงล็อตตัวอย่าง `GF-2026-001` และเปิดดูฟอร์มทำรายการได้ทุกเมนู

## เชื่อม Sepolia

1. Deploy สัญญา Solidity บน Sepolia เช่น ผ่าน Remix และจดที่อยู่สัญญา บัญชีที่ deploy จะเป็นผู้ดูแลหลัก
2. คัดลอก `.env.example` เป็น `.env.local` แล้วใส่ `VITE_CONTRACT_ADDRESS` และ `VITE_INFURA_API_KEY` จากโปรเจกต์ Infura ที่เปิดใช้ Sepolia จากนั้นเปิด Vite ใหม่
3. ให้ผู้ดูแลหลักเชื่อม MetaMask และใช้เมนูกำหนดสิทธิ์เพื่อเพิ่มบัญชีเกษตรกร ผู้ขนส่ง หรือผู้จัดจำหน่าย บัญชีที่ทำธุรกรรมต้องมี Sepolia ETH สำหรับค่า gas

ค่าที่ขึ้นต้นด้วย `VITE_` จะถูกใส่ไว้ในไฟล์ที่ส่งถึงเบราว์เซอร์ ให้ใช้ Infura API key ที่ตั้งใจเปิดใช้จากหน้าเว็บ จำกัดการใช้งานของ key ในแดชบอร์ดของ Infura ตามที่รองรับ และเก็บ API secret กับ private key ไว้นอกโปรเจกต์

## GitHub Pages

1. นำโปรเจกต์ขึ้น repository บน branch `main`
2. ตั้งค่า **Settings → Pages → Build and deployment → Source** เป็น **GitHub Actions**
3. ที่ **Settings → Secrets and variables → Actions → Variables** เพิ่ม repository variables ชื่อ `VITE_CONTRACT_ADDRESS` และ `VITE_INFURA_API_KEY`
4. รัน workflow **Deploy GreenFarm to GitHub Pages** จากแท็บ Actions หรือ push ไปที่ `main` เพื่อให้ workflow ทำงาน

GitHub Pages ให้บริการไฟล์ที่บิลด์แล้วจาก `dist/` ข้อมูลอยู่บน Sepolia จึงปิดเครื่องได้หลังเผยแพร่เว็บ

## ฟังก์ชันในหน้าเว็บ

ค้นหาล็อตด้วย Batch ID และดูประวัติแบบแบ่งหน้าได้โดยไม่ต้องเชื่อมกระเป๋า ไซด์บาร์เปิดดูฟอร์มได้ทุกเมนู ปุ่มยืนยันธุรกรรมจะแสดงตามบทบาท ผู้ครอบครอง ผู้รับมอบ และสถานะของล็อต ผู้ดูแลหลักกำหนดและถอนสิทธิ์ได้ ช่องตรวจสิทธิ์ใช้ค้นบทบาทของบัญชีใดก็ได้ รายการที่เขียนลงเชนจะแสดงลิงก์ไปยังธุรกรรมเมื่อส่งสำเร็จ

## ภาพการทดสอบบน Sepolia

ล็อตทดสอบ `GF-TEST-001`

<details>
<summary>กำหนดและตรวจสิทธิ์บัญชี (01–02)</summary>

![ภาพที่ 01](docs/screenshots/01.png)

![ภาพที่ 02](docs/screenshots/02.png)

</details>

<details>
<summary>ลงทะเบียนล็อต (03–05)</summary>

![ภาพที่ 03](docs/screenshots/03.png)

![ภาพที่ 04](docs/screenshots/04.png)

![ภาพที่ 05](docs/screenshots/05.png)

</details>

<details>
<summary>เสนอ ยกเลิก และรับมอบล็อต (06–11)</summary>

![ภาพที่ 06](docs/screenshots/06.png)

![ภาพที่ 07](docs/screenshots/07.png)

![ภาพที่ 08](docs/screenshots/08.png)

![ภาพที่ 09](docs/screenshots/09.png)

![ภาพที่ 10](docs/screenshots/10.png)

![ภาพที่ 11](docs/screenshots/11.png)

</details>

<details>
<summary>อัปเดตขั้นตอน บันทึกผลตรวจ และรายงานปัญหา (12–18)</summary>

![ภาพที่ 12](docs/screenshots/12.png)

![ภาพที่ 13](docs/screenshots/13.png)

![ภาพที่ 14](docs/screenshots/14.png)

![ภาพที่ 15](docs/screenshots/15.png)

![ภาพที่ 16](docs/screenshots/16.png)

![ภาพที่ 17](docs/screenshots/17.png)

![ภาพที่ 18](docs/screenshots/18.png)

</details>

<details>
<summary>เรียกคืนและปิดการเรียกคืน (19–23)</summary>

![ภาพที่ 19](docs/screenshots/19.png)

![ภาพที่ 20](docs/screenshots/20.png)

![ภาพที่ 21](docs/screenshots/21.png)

![ภาพที่ 22](docs/screenshots/22.png)

![ภาพที่ 23](docs/screenshots/23.png)

</details>

<details>
<summary>ส่งมอบให้ผู้จัดจำหน่ายและอัปเดตถึงร้านค้า (24–27)</summary>

![ภาพที่ 24](docs/screenshots/24.png)

![ภาพที่ 25](docs/screenshots/25.png)

![ภาพที่ 26](docs/screenshots/26.png)

![ภาพที่ 27](docs/screenshots/27.png)

</details>
