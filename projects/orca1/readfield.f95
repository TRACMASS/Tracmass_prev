SUBROUTINE readfields

  USE mod_param
  USE mod_vel
  
  USE mod_time
  USE mod_grid
  USE mod_name
  USE mod_vel
  USE mod_traj
  USE mod_getfile
  use mod_seed
  use mod_tempsalt

#ifdef tempsalt
  USE mod_dens
  USE mod_stat
#endif
  IMPLICIT none
  
  
  ! = Loop variables
  INTEGER                                      :: i, j, k ,kk, im, ip, jm, jp, imm, ii, jmm, jpp, l
  INTEGER                                      :: kbot,ktop
  INTEGER, SAVE                                :: ntempus=0,ntempusb=0,nread, currYear2
  ! = Variables used for getfield procedures
  CHARACTER (len=200)                          :: fieldFile
  ! = Variables for filename generation
  CHARACTER (len=200)                          :: dataprefix
!  REAL*8, ALLOCATABLE, DIMENSION(:,:)          :: zstot,zstou,zstov
  REAL*8, ALLOCATABLE, DIMENSION(:,:,:)        :: xxx
  REAL*4 dd,hu,hv,uint,vint,zint,hh,h0

  REAL*8, ALLOCATABLE, DIMENSION(:,:)          :: zstot,zstou,zstov
#ifdef initxyt
  INTEGER, PARAMETER :: NTID=73
  INTEGER, PARAMETER :: IJKMAX2=7392 ! for distmax=0.25 and 32 days

  INTEGER, SAVE, ALLOCATABLE, DIMENSION(:,:,:) :: ntimask
  REAL*4 , SAVE, ALLOCATABLE, DIMENSION(:,:,:) :: trajinit
#endif

  
#ifdef tempsalt
 REAL*4, ALLOCATABLE, DIMENSION(:)     :: rhozvec, depthzvec, latvec
 REAL*4 ,ALLOCATABLE, DIMENSION(:)     :: tmpzvec, salzvec
#endif

 LOGICAL around
 
  start1D  = [ 1]
  count1D  = [KM]
  start2D  = [subGridImin ,subGridJmin ,  1 , 1 ]
  count2D  = [         imt,        jmt ,  1 , 1 ]
  map2D    = [          1 ,          2 ,  3 , 4 ]  
  start3D  = [subGridImin ,subGridJmin ,  1 , 1 ]
  count3D  = [         imt,        jmt , KM , 1 ]
  map3D    = [          1 ,          2 ,  3 , 4 ] 


!---------------------------------------------------------------

#ifdef initxyt
  alloCondGrid: if ( .not. allocated (ntimask) ) then
     allocate ( ntimask(NTID,IJKMAX2,3) , trajinit(NTID,IJKMAX2,3) )
  endif alloCondGrid
#endif
 alloCondUVW: if(.not. allocated (xxx)) then
!    allocate ( zstot(imt,jmt),zstou(imt,jmt),zstov(imt,jmt) )
!    allocate ( ubol(imt,jmt,km),vbol(imt,jmt,km))
    allocate ( xxx(imt,jmt,km))
#ifdef tempsalt
   allocate ( tmpzvec(km), salzvec(km), rhozvec(km), depthzvec(km), latvec(km))
#endif
 endif alloCondUVW
 
 call datasetswap
 call updateClock

! === Initialising fields ===
 initFieldcond: if(ints.eq.intstart) then
 nread=0

#ifdef initxyt
    ! Time for individual start positions
    if(IJKMAX2.eq.7392) open(84,file=trim(inDataDir)//'topo/masktime_32_025', &
         form='unformatted')
    read(84) trajinit
    close(84)
    j=0
    do k=1,NTID
       do i=1,IJKMAX2
          if(trajinit(k,i,3).ne.0.) then
             j=j+1
#if orca025l75h6
             trajinit(k,i,3)=float(kst2)-0.5
             !   print *,j,trajinit(k,i,:)
#endif
          endif
       enddo
       ! print *,k,j
    enddo
    ijkst=0
    ! print *,'ijkmax=',j,IJKMAX2,ijkmax
    if(j.ne.IJKMAX2) then
       stop 4396
    endif
#endif

 CurrYear2=currYear-1
 endif initFieldcond
 
 if(currMon==1) CurrYear2 = CurrYear2+1
 if(CurrYear2==2006) CurrYear2=1996
! if(CurrYear2==1998) CurrYear2=1996

dataprefix='ORCA1-SHC1_MM_19960101_19961231_grid_'
write(dataprefix(15:18),'(i4)') CurrYear2
write(dataprefix(24:27),'(i4)') CurrYear2
fieldFile = trim(inDataDir)//'fields/'//trim(dataprefix)!
!print *, fieldFile
nread= nread+1
if(nread==13) nread=1
start2D  = [subGridImin ,subGridJmin ,  nread , 1 ]
start3D  = [subGridImin ,subGridJmin ,  1 , nread ]
  
hs(:,     :, nsp) = get2DfieldNC(trim(fieldFile)//'T.nc', 'sossheig')
hs(imt+1, :, nsp) = hs(1,:,nsp)

 do k=1,km
   dzt(1:imt,1:jmt,k,nsp) = dztb(1:imt,1:jmt,km+1-k) 
 end do
   dzt(:,:,KM,nsp) = dzt(:,:,KM,nsp) + hs(1:imt,1:jmt,nsp)


#if defined tempsalt 
 xxx(:,:,:) = get3DfieldNC(trim(fieldFile)//'T.nc', 'votemper')
 tem(:,:,:,nsp) = xxx(:,:,km:1:-1)
 
 xxx(:,:,:) = get3DfieldNC(trim(fieldFile)//'T.nc', 'vosaline')
 sal(:,:,:,nsp) = xxx(:,:,km:1:-1)
 
 depthzvec = 0.
 do j=1,JMT
    latvec=-80+1./12.*float(j+subGridJmin-1)
    do i=1,IMT
       tmpzvec = tem(i,j,:,nsp)
       salzvec = sal(i,j,:,nsp)
       call statvd(tmpzvec, salzvec, rhozvec ,km ,depthzvec ,latvec)
       rho(i,j,:,nsp)=rhozvec - 1000.
    end do
 end do
#endif     

 uvel = get3DfieldNC(trim(fieldFile)//'U.nc', 'vozocrtx')
 xxx  = get3DfieldNC(trim(fieldFile)//'U.nc', 'vozoeivu')
 uvel = uvel + xxx
 
 vvel = get3DfieldNC(trim(fieldFile)//'V.nc', 'vomecrty')
 xxx  = get3DfieldNC(trim(fieldFile)//'V.nc', 'vomeeivv')
 vvel = vvel + xxx

 do i=1,IMT
  do j=1,JMT
   jp=j+1
   if(jp.eq.jmt+1) jp=jmt
   do k=2,KM
    uflux(i,j,km+1-k,nsp) = uvel(i,j,k) * dyu(i,j) * dzu(i,j,k) 
    vflux(i,j,km+1-k,nsp) = vvel(i,j,k) * dxv(i,j) * dzv(i,j,k) 
   enddo
    uflux(i,j,km    ,nsp) = uvel(i,j,1) * dyu(i,j) * ( dzu(i,j,1)+ 0.5*( hs(i,j,nsp)+hs(i+1,j,nsp) ) )
    vflux(i,j,km    ,nsp) = vvel(i,j,1) * dxv(i,j) * ( dzv(i,j,1)+ 0.5*( hs(i,j,nsp)+hs(i,jp ,nsp) ) )
  enddo
 enddo


 do i=1,IMT
 do j=1,JMT-1
 do k=1,KM
!  if(k>kmv(i,j) .and. vflux(i,j,km+1-k,nsp)/=0. ) then
  if(k>kmv(i,j) .and. vvel(i,j,k)/=0. ) then
   print *,'vflux=',vflux(i,j,km+1-k,nsp),vvel(i,j,k),i,j,k,kmv(i,j),nsp
   stop 4966
  endif
  
  
    if(k>kmv(i,j) .and. vvel(i,j,k)/=0. ) then
   print *,'vflux=',vflux(i,j,km+1-k,nsp),vvel(i,j,k),i,j,k,kmv(i,j),nsp
   stop 4966
  endif


 enddo
 enddo
 enddo



#ifdef drifter
! average velocity/transport to simulate drifter trajectories
kbot=65 ; ktop=66 ! number of surface layers to integrate over 
uint=0. ; vint=0. ; zint=0.
do k=kbot,ktop
   uint = uint + uflux(:,:,k,nsp) ! integrated transport
   vint = vint + vflux(:,:,k,nsp)
   zint = zint + dz(k)          ! total depth of drougued drifter
end do
! weighted transport for each layer
do k=kbot,KM
   uflux(:,:,k,nsp) = uint*dz(k)/zint 
   vflux(:,:,k,nsp) = vint*dz(k)/zint
enddo
#endif

!print *,nread,ints,ts,uflux(270,97,KM,:),uvel(270,97,1)
!stop 4856
 !---



#ifdef initxyt
! Set the initial trajectory positions
!ijkst(:,5)=ntimask(ntempus,:)
#ifdef orca025l75h6
if( mod(ints,24/ngcm*5).eq.1 .or. ints.le.2) ntempus=ntempus+1
if(ntempus.ne.ntempusb .and. ntempus.le.NTID) then
ntempusb=ntempus
!print *,'ints=',ints,' ntempus=',ntempus,' ntempusb=',ntempusb
#else
if(ints.le.NTID) then
#endif

   
do ntrac=1,ijkmax
 if(trajinit(ntempus,ntrac,3).ne.0.) then
  ijkst(ntrac,4)=0
  ijkst(ntrac,5)=5
  ijkst(ntrac,6)=ijkst(ntrac,6)+1
  do l=1,3
   ijkst(ntrac,l)=trajinit(ntempus,ntrac,l)+1
   trj(ntrac,l)=trajinit(ntempus,ntrac,l)
!   if(l.eq.1) print *,ntrac,float(ijkst(ntrac,l)-1),trj(ntrac,l),float(ijkst(ntrac,l))
   if(trj(ntrac,l).gt.float(ijkst(ntrac,l)) .or. trj(ntrac,l).lt.float(ijkst(ntrac,l)-1)) then
    print *,l,ntrac,float(ijkst(ntrac,l)-1),trj(ntrac,l),float(ijkst(ntrac,l))
    stop 3946
   endif
  enddo
 else
  ijkst(ntrac,5)=0
  ijkst(ntrac,6)=0
 endif
enddo
endif
#ifdef orca025l75h6

#endif
if( mod(ints,24/ngcm*5).ne.1 .and. ints.gt.2) then
 ijkst=0 
endif
#endif


! deallocate ( temp3d_simp, temp2d_simp )
     
!#ifdef tempsalt
! deallocate ( tempb, saltb, rhob, depthb, latb )
!#endif

  return
end subroutine readfields



