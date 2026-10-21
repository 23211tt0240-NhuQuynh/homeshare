CREATE DATABASE HomeShare_1
GO

USE HomeShare_1
GO

-- 1. QUẢN LÝ NGƯỜI DÙNG 
CREATE TABLE nguoi_dung (
    id INT IDENTITY(1,1) PRIMARY KEY,
    ho_ten NVARCHAR(100) NOT NULL,
    ma_nguoi_dung as(
    case UPPER(vai_tro)
    when 'CHU TRO' then 'CT'
    when 'NGUOI THUE' THEN 'NT'
    WHEN 'QUAN TRI VIEN' THEN 'ADMIN'
    ELSE 'UNKNOW'
    END +RIGHT('000' +CAST(ID AS VARCHAR(10)),3)),

    so_dien_thoai VARCHAR(15) NOT NULL,
    email VARCHAR(100),
    mat_khau VARCHAR(255) NOT NULL,
    vai_tro VARCHAR(20) NOT NULL,
    diem_uy_tin INT DEFAULT 100,
    trang_thai VARCHAR(20) DEFAULT 'HOAT_DONG',
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_nguoi_dung_sdt UNIQUE (so_dien_thoai),
    CONSTRAINT uq_nguoi_dung_email UNIQUE (email),
    CONSTRAINT chk_nguoi_dung_vaitro CHECK (vai_tro IN ('QUAN TRI VIEN', 'CHU TRO', 'NGUOI THUE'))
)

CREATE TABLE xac_thuc_cccd (
    id INT PRIMARY KEY,
    nguoi_dung_id INT NOT NULL,
    so_cccd VARCHAR(20) NOT NULL,
    ho_ten_cccd NVARCHAR(100) NOT NULL,
    ngay_sinh DATE,
    anh_mat_truoc NVARCHAR(MAX) NOT NULL,
    anh_mat_sau NVARCHAR(MAX) NOT NULL,
    trang_thai_xac_thuc VARCHAR(20) DEFAULT 'CHO_DUYET',
    ngay_xac_thuc DATETIME,
    
    CONSTRAINT uq_xac_thuc_cccd UNIQUE (so_cccd),
    CONSTRAINT uq_xac_thuc_nguoidung UNIQUE (nguoi_dung_id),
    CONSTRAINT fk_xacthuc_nguoidung FOREIGN KEY (nguoi_dung_id) REFERENCES nguoi_dung(id) ON DELETE CASCADE,
    CONSTRAINT chk_xacthuc_trangthai CHECK (trang_thai_xac_thuc IN ('CHO_DUYET', 'DA_XAC_THUC', 'TU_CHOI'))
)

-- 2. QUẢN LÝ BẤT ĐỘNG SẢN & PHÒNG TRỌ
CREATE TABLE bat_dong_san (
    id INT PRIMARY KEY,
    chu_tro_id INT NOT NULL,
    ten_toa_nha NVARCHAR(150) NOT NULL,
    dia_chi_chi_tiet NVARCHAR(MAX) NOT NULL,
    tinh_thanh NVARCHAR(50) NOT NULL,
    quan_huyen NVARCHAR(50) NOT NULL,
    phuong_xa NVARCHAR(50),
    mo_ta NVARCHAR(MAX),
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_bds_chutro FOREIGN KEY (chu_tro_id) REFERENCES nguoi_dung(id) ON DELETE CASCADE
)

CREATE TABLE phong_tro (
    id INT PRIMARY KEY,
    bat_dong_san_id INT NOT NULL,
    ma_phong VARCHAR(50) NOT NULL,
    dien_tich DECIMAL(5,2) NOT NULL,
    gia_thue DECIMAL(12,2) NOT NULL,
    tien_coc DECIMAL(12,2) NOT NULL,
    gia_dien DECIMAL(10,2),
    gia_nuoc DECIMAL(10,2),
    gia_wifi DECIMAL(10,2),
    trang_thai VARCHAR(20) DEFAULT 'TRONG',
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_phongtro_maphong UNIQUE (bat_dong_san_id, ma_phong),
    CONSTRAINT fk_phongtro_bds FOREIGN KEY (bat_dong_san_id) REFERENCES bat_dong_san(id) ON DELETE CASCADE,
    CONSTRAINT chk_phongtro_trangthai CHECK (trang_thai IN ('TRONG', 'DA_COC', 'DA_THUE', 'BAO_TRI'))
)

CREATE TABLE danh_muc_tien_ich (
    id INT IDENTITY PRIMARY KEY,
    ten_tien_ich NVARCHAR(100) NOT NULL,
    bieu_tuong NVARCHAR(MAX),
    
    CONSTRAINT uq_tienich_ten UNIQUE (ten_tien_ich)
)

CREATE TABLE tien_ich_phong_tro (
    phong_tro_id INT NOT NULL,
    tien_ich_id INT NOT NULL,
    
    PRIMARY KEY (phong_tro_id, tien_ich_id),
    CONSTRAINT fk_tienichphong_phong FOREIGN KEY (phong_tro_id) REFERENCES phong_tro(id) ON DELETE CASCADE,
    CONSTRAINT fk_tienichphong_tienich FOREIGN KEY (tien_ich_id) REFERENCES danh_muc_tien_ich(id) ON DELETE CASCADE
)

CREATE TABLE hinh_anh_phong (
    id INT  PRIMARY KEY,
    phong_tro_id INT NOT NULL,
    url_anh NVARCHAR(MAX) NOT NULL,
    la_anh_chinh BIT DEFAULT 0,
    
    CONSTRAINT fk_hinhanh_phong FOREIGN KEY (phong_tro_id) REFERENCES phong_tro(id) ON DELETE CASCADE
)

-- 3. BÀI ĐĂNG & TƯƠNG TÁC
CREATE TABLE bai_dang_cho_thue (
    id INT  PRIMARY KEY,
    phong_tro_id INT NOT NULL,
    tieu_de NVARCHAR(200) NOT NULL,
    noi_dung NVARCHAR(MAX) NOT NULL,
    trang_thai VARCHAR(20) DEFAULT 'CHO_DUYET',
    la_bai_ghim BIT DEFAULT 0,
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_baidang_phong FOREIGN KEY (phong_tro_id) REFERENCES phong_tro(id) ON DELETE CASCADE,
    CONSTRAINT chk_baidang_trangthai CHECK (trang_thai IN ('CHO_DUYET', 'DA_DUYET', 'TU_CHOI', 'DA_AN'))
)

CREATE TABLE bao_cao_vi_pham_bai_dang (
    id INT IDENTITY(1,1) PRIMARY KEY,
    bai_dang_id INT NOT NULL,
    nguoi_bao_cao_id INT NOT NULL,
    ly_do NVARCHAR(MAX) NOT NULL,
    trang_thai VARCHAR(20) DEFAULT 'CHO_XU_LY',
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_baocao_baidang FOREIGN KEY (bai_dang_id) REFERENCES bai_dang_cho_thue(id) ON DELETE CASCADE,
    CONSTRAINT fk_baocao_nguoidung FOREIGN KEY (nguoi_bao_cao_id) REFERENCES nguoi_dung(id),
    CONSTRAINT chk_baocao_trangthai CHECK (trang_thai IN ('CHO_XU_LY', 'DA_XU_LY', 'BAC_BO'))
)

CREATE TABLE phong_tro_yeu_thich (
    nguoi_dung_id INT NOT NULL,
    phong_tro_id INT NOT NULL,
    ngay_luu DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (nguoi_dung_id, phong_tro_id),
    CONSTRAINT fk_yeuthich_nguoidung FOREIGN KEY (nguoi_dung_id) REFERENCES nguoi_dung(id),
    CONSTRAINT fk_yeuthich_phong FOREIGN KEY (phong_tro_id) REFERENCES phong_tro(id) ON DELETE CASCADE
)

--4. TÌM NGƯỜI Ở GHÉP & LỐI SỐNG
CREATE TABLE ho_so_loi_song_cu_dan (
    id INT PRIMARY KEY,
    nguoi_dung_id INT NOT NULL,
    gio_giac_sinh_hoat NVARCHAR(100),
    thoi_quen_hut_thuoc BIT DEFAULT 0,
    nuoi_thu_cung BIT DEFAULT 0,
    tinh_cach NVARCHAR(100),
    mo_ta_ban_than NVARCHAR(MAX),
    
    CONSTRAINT uq_hoso_nguoidung UNIQUE (nguoi_dung_id),
    CONSTRAINT fk_hoso_nguoidung FOREIGN KEY (nguoi_dung_id) REFERENCES nguoi_dung(id) ON DELETE CASCADE
)

CREATE TABLE bai_dang_tim_o_ghep (
    id INT PRIMARY KEY,
    nguoi_dang_id INT NOT NULL,
    phong_tro_id INT,
    tieu_de NVARCHAR(200) NOT NULL,
    mo_ta_yeu_cau NVARCHAR(MAX) NOT NULL,
    ngan_sach DECIMAL(12,2),
    trang_thai VARCHAR(20) DEFAULT 'DANG_TIM',
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_timoghep_nguoidang FOREIGN KEY (nguoi_dang_id) REFERENCES nguoi_dung(id) ON DELETE CASCADE,
    CONSTRAINT fk_timoghep_phong FOREIGN KEY (phong_tro_id) REFERENCES phong_tro(id),
    CONSTRAINT chk_timoghep_trangthai CHECK (trang_thai IN ('DANG_TIM', 'DA_TIM_DU', 'DONG'))
)

CREATE TABLE loi_moi_o_ghep (
    id INT PRIMARY KEY,
    bai_dang_id INT NOT NULL,
    nguoi_gui_id INT NOT NULL,
    nguoi_nhan_id INT NOT NULL,
    loi_nhan NVARCHAR(MAX),
    trang_thai VARCHAR(20) DEFAULT 'CHO_PHAN_HOI',
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_loimoi_baidang FOREIGN KEY (bai_dang_id) REFERENCES bai_dang_tim_o_ghep(id) ON DELETE CASCADE,
    CONSTRAINT fk_loimoi_nguoigui FOREIGN KEY (nguoi_gui_id) REFERENCES nguoi_dung(id),
    CONSTRAINT fk_loimoi_nguoinhan FOREIGN KEY (nguoi_nhan_id) REFERENCES nguoi_dung(id),
    CONSTRAINT chk_loimoi_trangthai CHECK (trang_thai IN ('CHO_PHAN_HOI', 'CHAP_NHAN', 'TU_CHOI'))
)

-- 5. ĐẶT PHÒNG, ESCROW & VẬN HÀNH CƯ DÂN
CREATE TABLE don_dat_phong (
    id INT PRIMARY KEY,
    phong_tro_id INT NOT NULL,
    nguoi_thue_id INT NOT NULL,
    tien_coc DECIMAL(12,2) NOT NULL,
    ngay_du_kien_den DATE NOT NULL,
    trang_thai VARCHAR(30) DEFAULT 'CHO_THANH_TOAN',
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_datphong_phong FOREIGN KEY (phong_tro_id) REFERENCES phong_tro(id) ON DELETE CASCADE,
    CONSTRAINT fk_datphong_nguoithue FOREIGN KEY (nguoi_thue_id) REFERENCES nguoi_dung(id),
    CONSTRAINT chk_datphong_trangthai CHECK (trang_thai IN ('CHO_THANH_TOAN', 'DA_COC', 'DA_TRA_HET', 'DANG_XU_LY', 'DA_CHAP_NHAN', 'NHA_DANG_O', 'LICH_SU_DA_O', 'DA_HUY'))
)

CREATE TABLE giao_dich_giu_coc (
    id INT PRIMARY KEY,
    don_dat_phong_id INT NOT NULL,
    so_tien DECIMAL(12,2) NOT NULL,
    ma_giao_dich_qr VARCHAR(100),
    trang_thai VARCHAR(30) DEFAULT 'DANG_GIU_COC',
    ngay_thanh_toan DATETIME,
    ngay_giai_ngan DATETIME,
    
    CONSTRAINT uq_escrow_magiaodich UNIQUE (ma_giao_dich_qr),
    CONSTRAINT fk_escrow_datphong FOREIGN KEY (don_dat_phong_id) REFERENCES don_dat_phong(id) ON DELETE CASCADE,
    CONSTRAINT chk_escrow_trangthai CHECK (trang_thai IN ('DANG_GIU_COC', 'DA_GIAI_NGAN_CHU_TRO', 'DA_HOAN_TIEN_NGUOI_THUE', 'TRANH_CHAP'))
)

CREATE TABLE cu_dan_dang_o (
    id INT PRIMARY KEY,
    phong_tro_id INT NOT NULL,
    nguoi_dung_id INT NOT NULL,
    ngay_bat_dau DATE NOT NULL,
    ngay_ket_thuc DATE,
    trang_thai VARCHAR(20) DEFAULT 'DANG_O',
    
    CONSTRAINT fk_cudan_phong FOREIGN KEY (phong_tro_id) REFERENCES phong_tro(id) ON DELETE CASCADE,
    CONSTRAINT fk_cudan_nguoidung FOREIGN KEY (nguoi_dung_id) REFERENCES nguoi_dung(id),
    CONSTRAINT chk_cudan_trangthai CHECK (trang_thai IN ('DANG_O', 'DA_CHUYEN_DI'))
)

CREATE TABLE phuong_tien_cu_dan (
    id INT PRIMARY KEY,
    cu_dan_id INT NOT NULL,
    loai_xe NVARCHAR(50) NOT NULL,
    bien_so VARCHAR(20) NOT NULL,
    mau_xe NVARCHAR(50),
    
    CONSTRAINT uq_phuongtien_bienso UNIQUE (bien_so),
    CONSTRAINT fk_phuongtien_cudan FOREIGN KEY (cu_dan_id) REFERENCES cu_dan_dang_o(id) ON DELETE CASCADE
)

CREATE TABLE bien_ban_nhan_phong_checkin (
    id INT PRIMARY KEY,
    don_dat_phong_id INT NOT NULL,
    chi_so_dien_ban_dau DECIMAL(10,2) NOT NULL,
    chi_so_nuoc_ban_dau DECIMAL(10,2) NOT NULL,
    tinh_trang_co_so_vat_chat NVARCHAR(MAX),
    ma_qr_checkin VARCHAR(100),
    xac_nhan_nguoi_thue BIT DEFAULT 0,
    ngay_checkin DATETIME,
    
    CONSTRAINT uq_checkin_datphong UNIQUE (don_dat_phong_id),
    CONSTRAINT fk_checkin_datphong FOREIGN KEY (don_dat_phong_id) REFERENCES don_dat_phong(id) ON DELETE CASCADE
)

CREATE TABLE bien_ban_tra_phong_checkout (
    id INT PRIMARY KEY,
    cu_dan_id INT NOT NULL,
    chi_so_dien_cuoi DECIMAL(10,2) NOT NULL,
    chi_so_nuoc_cuoi DECIMAL(10,2) NOT NULL,
    hu_hong_thiet_hai NVARCHAR(MAX),
    chi_phi_khau_tru DECIMAL(12,2) DEFAULT 0,
    xac_nhan_hai_ben BIT DEFAULT 0,
    ngay_checkout DATETIME,
    
    CONSTRAINT uq_checkout_cudan UNIQUE (cu_dan_id),
    CONSTRAINT fk_checkout_cudan FOREIGN KEY (cu_dan_id) REFERENCES cu_dan_dang_o(id) ON DELETE CASCADE
)

CREATE TABLE nhat_ky_vi_pham_noi_quy (
    id INT PRIMARY KEY,
    cu_dan_id INT NOT NULL,
    noi_dung_vi_pham NVARCHAR(MAX) NOT NULL,
    muc_phat DECIMAL(12,2) DEFAULT 0,
    ngay_ghi_nhan DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_vipham_cudan FOREIGN KEY (cu_dan_id) REFERENCES cu_dan_dang_o(id) ON DELETE CASCADE
)

-- 6. TRÒ CHUYỆN & THÔNG BÁO
CREATE TABLE cuoc_tro_chuyen (
    id INT PRIMARY KEY,
    phong_tro_id INT,
    nguoi_dung_1_id INT NOT NULL,
    nguoi_dung_2_id INT NOT NULL,
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_trochuyen_phong FOREIGN KEY (phong_tro_id) REFERENCES phong_tro(id) ON DELETE SET NULL,
    CONSTRAINT fk_trochuyen_user1 FOREIGN KEY (nguoi_dung_1_id) REFERENCES nguoi_dung(id),
    CONSTRAINT fk_trochuyen_user2 FOREIGN KEY (nguoi_dung_2_id) REFERENCES nguoi_dung(id)
)

CREATE TABLE tin_nhan (
    id INT PRIMARY KEY,
    cuoc_tro_chuyen_id INT NOT NULL,
    nguoi_gui_id INT NOT NULL,
    noi_dung NVARCHAR(MAX) NOT NULL,
    url_tep_kem NVARCHAR(MAX),
    da_doc BIT DEFAULT 0,
    ngay_gui DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_tinnhan_cuoctrochuyen FOREIGN KEY (cuoc_tro_chuyen_id) REFERENCES cuoc_tro_chuyen(id) ON DELETE CASCADE,
    CONSTRAINT fk_tinnhan_nguoigui FOREIGN KEY (nguoi_gui_id) REFERENCES nguoi_dung(id)
)

CREATE TABLE thong_bao (
    id INT PRIMARY KEY,
    nguoi_dung_id INT NOT NULL,
    tieu_de NVARCHAR(200) NOT NULL,
    noi_dung NVARCHAR(MAX) NOT NULL,
    loai_thong_bao VARCHAR(50),
    da_doc BIT DEFAULT 0,
    ngay_tao DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_thongbao_nguoidung FOREIGN KEY (nguoi_dung_id) REFERENCES nguoi_dung(id) ON DELETE CASCADE
)

-- 7. QUYẾT TOÁN & KIỂM TOÁN HỆ THỐNG
CREATE TABLE quyet_toan_chu_tro (
    id INT PRIMARY KEY,
    chu_tro_id INT NOT NULL,
    tong_tien_giao_dich DECIMAL(12,2) NOT NULL,
    phi_hoa_hong_he_thong DECIMAL(12,2) NOT NULL,
    so_tien_thuc_nhan DECIMAL(12,2) NOT NULL,
    trang_thai VARCHAR(20) DEFAULT 'CHO_QUYET_TOAN',
    ngay_quyet_toan DATETIME,
    
    CONSTRAINT fk_quyettoan_chutro FOREIGN KEY (chu_tro_id) REFERENCES nguoi_dung(id) ON DELETE CASCADE,
    CONSTRAINT chk_quyettoan_trangthai CHECK (trang_thai IN ('CHO_QUYET_TOAN', 'DA_THANH_TOAN'))
)

CREATE TABLE nhat_ky_kiem_toan_he_thong (
    id INT PRIMARY KEY,
    nguoi_thuc_hien_id INT,
    hanh_dong VARCHAR(100) NOT NULL,
    chi_tiet NVARCHAR(MAX),
    dia_chi_ip VARCHAR(45),
    ngay_ghi_nhan DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_kiemtoan_nguoidung FOREIGN KEY (nguoi_thuc_hien_id) REFERENCES nguoi_dung(id) ON DELETE SET NULL
)



----- INSERT -----
-- 1. THÊM NGƯỜI DÙNG
INSERT INTO nguoi_dung (ho_ten, so_dien_thoai, email, mat_khau, vai_tro) 
VALUES 
(N'Nguyễn Văn Quản Trị', '0901000001', 'admin@homeshare.com', 'pass123', 'QUAN TRI VIEN'), 
(N'Trần Văn Chủ Trọ',   '0902000002', 'chutro@homeshare.com', 'pass123', 'CHU TRO'),       
(N'Lê Thị Người Thuê', '0903000003', 'nguoithue@homeshare.com', 'pass123', 'NGUOI THUE')

-- 2. ĐÃ XÁC THỰC CCCD 
INSERT INTO xac_thuc_cccd (id, nguoi_dung_id, so_cccd, ho_ten_cccd, ngay_sinh, anh_mat_truoc, anh_mat_sau, trang_thai_xac_thuc)
VALUES 
(1, 2, '012345678901', N'TRẦN VĂN CHỦ TRỌ', '1985-05-20', 'https://img.com/cccd_truoc.jpg', 'https://img.com/cccd_sau.jpg', 'DA_XAC_THUC')

-- 3. BẤT ĐỘNG SẢN 
INSERT INTO bat_dong_san (id, chu_tro_id, ten_toa_nha, dia_chi_chi_tiet, tinh_thanh, quan_huyen, phuong_xa, mo_ta)
VALUES 
(1, 2, N'Tòa nhà HomeShare Bình Thạnh', N'123 Điện Biên Phủ', N'TP. Hồ Chí Minh', N'Quận Bình Thạnh', N'Phường 15', N'Căn hộ dịch vụ mới xây, an ninh 24/7')

-- 4. PHÒNG TRỌ 
INSERT INTO phong_tro (id, bat_dong_san_id, ma_phong, dien_tich, gia_thue, tien_coc, gia_dien, gia_nuoc, gia_wifi, trang_thai)
VALUES 
(101, 1, 'P.101', 25.0, 4500000, 4500000, 3500, 100000, 100000, 'TRONG'),
(102, 1, 'P.102', 30.0, 5500000, 5500000, 3500, 100000, 100000, 'TRONG')

-- 5. DANH MỤC TIỆN ÍCH 
INSERT INTO danh_muc_tien_ich (ten_tien_ich, bieu_tuong)
VALUES 
(N'Máy lạnh', 'icon-air-conditioner'),
(N'Máy giặt', 'icon-washing-machine'),
(N'Bãi đỗ xe', 'icon-parking')

-- 6. TIỆN ÍCH PHÒNG TRỌ 
INSERT INTO tien_ich_phong_tro (phong_tro_id, tien_ich_id)
VALUES 
(101, 1),
(101, 2),
(102, 1),
(102, 3)

-- 7. BÀI ĐĂNG CHO THUÊ
INSERT INTO bai_dang_cho_thue (id, phong_tro_id, tieu_de, noi_dung, trang_thai, la_bai_ghim)
VALUES 
(1, 101, N'Cho thuê phòng trọ full nội thất Bình Thạnh', N'Phòng sạch đẹp, ban công thoáng mát, giờ giấc tự do.', 'DA_DUYET', 1)

-- 8. ĐẶT PHÒNG 
INSERT INTO don_dat_phong (id, phong_tro_id, nguoi_thue_id, tien_coc, ngay_du_kien_den, trang_thai)
VALUES 
(1, 101, 3, 4500000, '2026-10-01', 'DA_COC')

-- 9. GIAO DỊCH GIỮ CỌC 
INSERT INTO giao_dich_giu_coc (id, don_dat_phong_id, so_tien, ma_giao_dich_qr, trang_thai, ngay_thanh_toan)
VALUES 
(1, 1, 4500000, 'QR_TXN_123456789', 'DANG_GIU_COC', GETDATE())

---- TRUY VẤN THỬ ----
SELECT id, ma_nguoi_dung, ho_ten, vai_tro FROM nguoi_dung